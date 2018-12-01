defmodule ExWire.Sync.WarpProcessor.PowProcessor do
  @moduledoc """
  PowProcessor helps build a proper blockchain state from the data
  received from a warp of a proof-of-work chain.

  When we receive a warp manifest from peers, it contains a list
  of block and state chunks that contain data about the most recent
  several thousand blocks and all of the account state data for the
  most recently included block.

  For each block chunk, we store each transaction and receipt, returning a
  transactions root and receipts root, which we use to complete the block
  header and store all of these (the block by hash, the transactions and the
  receipts) to our permanent database.

  For each state chunk, we have abridged data about a list of accounts. First,
  we process those state chunks into a set of encoded account data that are
  stored to the trie. Then, given a state root, we process each of these account
  entries, storing them into a trie to get the state root. We will verify
  this state root against the root given in the warp manifest to ensure we've
  properly processed each account.

  For processing the state root, there's one complication: account data may
  be split over multiple state chunks. It would be slow to wait and merge
  this data prior to committing any blocks, so instead we check to see if there
  is any previous account storage prior to processing account entries which
  may have been split up. Note: only the first or last entry in a state chunk
  could have been split up, since the middle ones must, be definition, fit
  properly in the state chunk.
  """

  alias Block.Header
  alias Blockchain.Block
  alias ExthCrypto.Hash.Keccak
  alias ExWire.Packet.Capability.Par.SnapshotData.{BlockChunk, StateChunk}
  alias ExWire.Packet.Capability.Par.SnapshotData.BlockChunk.BlockData
  alias ExWire.Packet.Capability.Par.SnapshotData.StateChunk.RichAccount
  alias MerklePatriciaTree.{Trie, TrieStorage}

  @type account_state :: {EVM.hash(), binary()}
  @empty_code_hash Keccak.kec(<<>>)
  @empty_trie Trie.empty_trie_root_hash()

  @doc """
  Processes a block chunk, returning the block numbers which were processed,
  the best block which was generated (which can be put in the block tree),
  and the updated trie (which has not yet been committed). See `process_block`
  for more information on how blocks are processed.
  """
  @spec process_block_chunk(BlockChunk.t(), Trie.t()) ::
          {MapSet.t(integer()), Block.t(), Trie.t()}
  def process_block_chunk(block_chunk, trie) do
    {_, _, next_trie, processed_blocks, block} =
      Enum.reduce(
        block_chunk.block_data_list,
        {block_chunk.number, block_chunk.hash, trie, MapSet.new(), nil},
        fn block_data, {number, parent_hash, curr_trie, curr_processed_blocks, _} ->
          {next_trie, block} =
            process_block(
              block_data,
              parent_hash,
              number + 1,
              curr_trie
            )

          {
            number + 1,
            block.block_hash,
            next_trie,
            MapSet.put(curr_processed_blocks, block.header.number),
            block
          }
        end
      )

    {processed_blocks, block, next_trie}
  end

  @doc """
  Processes a state chunk, returning a list of `account_state` entries which need
  to be placed into the state trie, as well as the trie which contains the account
  data which should be stored. The trie has not yet been committed.

  See `process_account` for more details on how we process each account entry.
  """
  @spec process_state_chunk(StateChunk.t(), Trie.t()) :: {list(account_state()), Trie.t()}
  def process_state_chunk(state_chunk, trie) do
    account_entries_count = Enum.count(state_chunk.account_entries)

    {next_trie, account_states, _} =
      Enum.reduce(state_chunk.account_entries, {trie, [], 0}, fn {address_hash, rich_account},
                                                                 {curr_trie, curr_account_states,
                                                                  num} ->
        {next_trie, account_state} =
          process_account(
            address_hash,
            rich_account,
            curr_trie,
            num == 0 || num == account_entries_count - 1
          )

        {next_trie, [account_state | curr_account_states], num + 1}
      end)

    {Enum.reverse(account_states), next_trie}
  end

  @doc """
  Processes a single block from within a block chunk. This verifies the block
  headers, builds stores each transaction and builds a transaction root, stores
  each receipt and builds a receipts root, and returns the block as well as the
  updated trie.

  TODO: Validate the block headers before accepting the block.
  """
  @spec process_block(BlockData.t(), EVM.hash(), integer(), Trie.t()) :: {Trie.t(), Block.t()}
  def process_block(
        block_data,
        parent_hash,
        number,
        trie
      ) do
    # First, we need to validate some aspect of the block, that's currently
    # ommited.

    # Next, store transactions and verify root
    {_, trie_with_trx, transactions_root} =
      Enum.reduce(block_data.header.transactions_rlp, {0, trie, @empty_trie}, fn trx_rlp,
                                                                                 {i, curr_trie,
                                                                                  curr_root} ->
        {subtrie, updated_trie} =
          TrieStorage.update_subtrie_key(
            curr_trie,
            curr_root,
            ExRLP.encode(i),
            ExRLP.encode(trx_rlp)
          )

        updated_root_hash = TrieStorage.root_hash(subtrie)

        {i + 1, updated_trie, updated_root_hash}
      end)

    # Then, store receipts and verify root
    {_, trie_with_trx_and_receipts, receipts_root} =
      Enum.reduce(block_data.receipts_rlp, {0, trie_with_trx, @empty_trie}, fn receipt_rlp,
                                                                               {i, curr_trie,
                                                                                curr_root} ->
        {subtrie, updated_trie} =
          TrieStorage.update_subtrie_key(
            curr_trie,
            curr_root,
            ExRLP.encode(i),
            ExRLP.encode(receipt_rlp)
          )

        updated_root_hash = TrieStorage.root_hash(subtrie)

        {i + 1, updated_trie, updated_root_hash}
      end)

    block = get_block(block_data, parent_hash, number, transactions_root, receipts_root)

    # Store the block to our db, trying not to repeat encodings of our
    # transactions and ommers. But.. we do.
    block_encoded_rlp =
      [
        Header.serialize(block.header),
        block_data.header.transactions_rlp,
        block_data.header.ommers_rlp
      ]
      |> ExRLP.encode()

    {
      TrieStorage.put_raw_key!(trie_with_trx_and_receipts, block.block_hash, block_encoded_rlp),
      block
    }
  end

  # Returns a block struct given pieces of information compiled from data in the
  # block chunk.
  @spec get_block(BlockData.t(), EVM.hash(), integer(), EVM.hash(), EVM.hash()) :: Block.t()
  defp get_block(block_data, parent_hash, number, transactions_hash, receipts_root) do
    ommers_hash = get_ommers_hash(block_data.header.ommers_rlp)

    header = %Header{
      parent_hash: parent_hash,
      ommers_hash: ommers_hash,
      beneficiary: block_data.header.author,
      state_root: block_data.header.state_root,
      transactions_root: transactions_hash,
      receipts_root: receipts_root,
      logs_bloom: block_data.header.logs_bloom,
      difficulty: block_data.header.difficulty,
      number: number,
      gas_limit: block_data.header.gas_limit,
      gas_used: block_data.header.gas_used,
      timestamp: block_data.header.timestamp,
      extra_data: block_data.header.extra_data,
      mix_hash: block_data.header.mix_hash,
      nonce: block_data.header.nonce
    }

    %Block{
      block_hash: Header.hash(header),
      header: header,
      transactions: block_data.header.transactions,
      receipts: block_data.receipts,
      ommers: block_data.header.ommers
    }
  end

  @doc """
  Processes a single account entry from a state chunk. We build a storage
  root of the block from the given storage that (note: this may be added
  to via `reprocess_account` for the first or last block of a chunk).
  Additionally, we calculate the code hash, etc, and return the RLP-encoded
  account data which should be stored to the trie.

  If `keep_storage` is true, we return the raw storage data which is required
  for reprocessing the block (if it may be split over multiple state chunks).
  """
  @spec process_account(EVM.hash(), RichAccount.t(), Trie.t(), boolean()) ::
          {Trie.t(), {EVM.Address.t(), binary(), nil | %{}}}
  def process_account(address_hash, rich_account, trie, keep_storage) do
    # First, we need to put the storage values for the account into
    # a new subtree, getting the new state root.
    {new_trie, storage_root_hash} =
      process_account_storage(rich_account.storage, trie, @empty_trie)

    # Then, we need to put the code hash
    {new_trie_2, code_hash} =
      case rich_account.code_flag do
        :no_code ->
          {new_trie, @empty_code_hash}

        :has_code ->
          code_hash = Keccak.kec(rich_account.code)

          {
            TrieStorage.put_raw_key!(new_trie, code_hash, rich_account.code),
            code_hash
          }

        :has_repeat_code ->
          {new_trie, rich_account.code}
      end

    # Store the account to our db
    account_encoded_rlp =
      [
        rich_account.nonce,
        rich_account.balance,
        storage_root_hash,
        code_hash
      ]
      |> ExRLP.encode()

    {new_trie_2,
     {address_hash, account_encoded_rlp, if(keep_storage, do: rich_account.storage, else: nil)}}
  end

  # Builds an account storage root trie from a given starting hash (e.g. a blank trie),
  # as well as a list of pre-hashed key-value pairs. Note: this will get called when
  # the account is first processed, and may get called again in re-processing.
  @spec process_account_storage(list({EVM.hash(), <<_::256>>}), Trie.t(), EVM.hash()) ::
          {Trie.t(), EVM.hash()}
  defp process_account_storage(storage, trie, root_hash) do
    Enum.reduce(storage, {trie, root_hash}, fn {k, v}, {curr_trie, curr_root} ->
      {subtrie, updated_trie} = TrieStorage.update_subtrie_key(curr_trie, curr_root, k, v)

      updated_root_hash = TrieStorage.root_hash(subtrie)

      {updated_trie, updated_root_hash}
    end)
  end

  @doc """
  Given a list of account states and the current state trie, returns
  a new state trie with the accounts included. This is effectively
  just `Enum.reduce(accounts, state_trie, &Account.put_account/1)`,
  but more complicated due to repeat accounts and certain nuances (such
  as the keys being pre-hashed).

  We return a state trie whose root should be used for the next call
  to `process_account_states`.
  """
  @spec process_account_states(list(account_state()), Trie.t()) :: Trie.t()
  def process_account_states(account_states, state_trie) do
    next_state_trie =
      Enum.reduce(account_states, state_trie, fn
        {address_hash, account_encoded_rlp, nil}, curr_state_trie ->
          TrieStorage.update_key(curr_state_trie, address_hash, account_encoded_rlp)

        {address_hash, account_encoded_rlp, storage}, curr_state_trie ->
          existing_account_rlp = TrieStorage.get_key(curr_state_trie, address_hash)

          {new_account_rlp, new_state_trie} =
            if existing_account_rlp do
              reprocess_account(storage, existing_account_rlp, curr_state_trie)
            else
              {account_encoded_rlp, curr_state_trie}
            end

          TrieStorage.update_key(new_state_trie, address_hash, new_account_rlp)
      end)

    next_state_trie
  end

  # Some later accounts may be included in different state chunks, and therefore
  # in different "account states." For those accounts, we need to pull the existing
  # state trie and add the storage data to that trie, versus overwriting what was
  # already there.
  @spec reprocess_account(list({EVM.hash(), <<_::256>>}), binary(), Trie.t()) ::
          {binary(), Trie.t()}
  defp reprocess_account(storage, existing_account_rlp, trie) do
    existing_account =
      existing_account_rlp
      |> ExRLP.decode()
      |> Blockchain.Account.deserialize()

    {new_trie, storage_root_hash} =
      process_account_storage(storage, trie, existing_account.storage_root)

    new_account_rlp =
      existing_account
      |> Map.put(:storage_root, storage_root_hash)
      |> Blockchain.Account.serialize()
      |> ExRLP.encode()

    {new_account_rlp, new_trie}
  end

  # Returns the ommers hash given the ommers RLP.
  @spec get_ommers_hash(list(binary())) :: EVM.hash()
  defp get_ommers_hash(ommers_rlp) do
    ommers_rlp
    |> ExRLP.encode()
    |> ExthCrypto.Hash.Keccak.kec()
  end
end
