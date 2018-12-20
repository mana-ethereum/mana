defmodule JSONRPC2.Bridge.Sync do
  alias Blockchain.Account
  alias Blockchain.Block
  alias Blockchain.Blocktree
  alias ExWire.PeerSupervisor
  alias ExWire.Sync
  alias JSONRPC2.Response.Block, as: ResponseBlock
  alias JSONRPC2.Response.Receipt, as: ResponseReceipt
  alias JSONRPC2.Response.Transaction, as: ResponseTransaction
  alias MerklePatriciaTree.TrieStorage

  @spec connected_peer_count :: 0 | non_neg_integer()
  def connected_peer_count, do: PeerSupervisor.connected_peer_count()

  @spec get_last_sync_block_stats() ::
          {non_neg_integer(), non_neg_integer(), non_neg_integer()} | false
  def get_last_sync_block_stats() do
    case Process.whereis(Sync) do
      nil ->
        false

      _ ->
        state = get_last_sync_state()

        {:ok, {block, _caching_trie}} =
          Blocktree.get_best_block(state.block_tree, state.chain, state.trie)

        {block.header.number, state.starting_block_number, state.highest_block_number}
    end
  end

  @spec get_last_sync_state() :: Sync.state()
  defp get_last_sync_state(), do: Sync.get_state()

  def get_block_by_number(number, include_full_transactions) do
    state_trie = get_last_sync_state().trie

    case Block.get_block(number, state_trie) do
      {:ok, block} -> ResponseBlock.new(block, include_full_transactions)
      _ -> nil
    end
  end

  def get_block_by_hash(hash, include_full_transactions) do
    state_trie = get_last_sync_state().trie

    case Block.get_block(hash, state_trie) do
      {:ok, block} -> ResponseBlock.new(block, include_full_transactions)
      _ -> nil
    end
  end

  def get_transaction_by_block_hash_and_index(block_hash, trx_index) do
    trie = get_last_sync_state().trie

    with {:ok, block} <- Block.get_block(block_hash, trie) do
      case Enum.at(block.transactions, trx_index) do
        nil -> nil
        transaction -> ResponseTransaction.new(transaction, block)
      end
    else
      _ -> nil
    end
  end

  def get_transaction_by_block_number_and_index(block_number, trx_index) do
    trie = get_last_sync_state().trie

    with {:ok, block} <- Block.get_block(block_number, trie) do
      case Enum.at(block.transactions, trx_index) do
        nil -> nil
        transaction -> ResponseTransaction.new(transaction, block)
      end
    else
      _ -> nil
    end
  end

  def get_block_transaction_count_by_number(number) do
    state_trie = get_last_sync_state().trie

    case Block.get_block(number, state_trie) do
      {:ok, block} ->
        block.transactions
        |> Enum.count()
        |> Exth.encode_unsigned_hex()

      _ ->
        nil
    end
  end

  def get_block_transaction_count_by_hash(hash) do
    state_trie = get_last_sync_state().trie

    case Block.get_block(hash, state_trie) do
      {:ok, block} ->
        block.transactions
        |> Enum.count()
        |> Exth.encode_unsigned_hex()

      _ ->
        nil
    end
  end

  def get_uncle_count_by_block_hash(hash) do
    state_trie = get_last_sync_state().trie

    case Block.get_block(hash, state_trie) do
      {:ok, block} ->
        block.ommers
        |> Enum.count()
        |> Exth.encode_unsigned_hex()

      _ ->
        nil
    end
  end

  def get_uncle_count_by_block_number(number) do
    state_trie = get_last_sync_state().trie

    case Block.get_block(number, state_trie) do
      {:ok, block} ->
        block.ommers
        |> Enum.count()
        |> Exth.encode_unsigned_hex()

      _ ->
        nil
    end
  end

  def get_starting_block_number do
    state = get_last_sync_state()

    Map.get(state, :starting_block_number, 0)
  end

  def get_highest_block_number do
    state = get_last_sync_state()

    Map.get(state, :highest_block_number, 0)
  end

  def get_code(address, block_number) do
    state_trie = get_last_sync_state().trie

    case Block.get_block(block_number, state_trie) do
      {:ok, block} ->
        block_state = TrieStorage.set_root_hash(state_trie, block.header.state_root)

        case Account.machine_code(block_state, address) do
          {:ok, code} -> Exth.encode_hex(code)
          _ -> nil
        end

      _ ->
        nil
    end
  end

  def get_balance(address, block_number) do
    state_trie = get_last_sync_state().trie

    case Block.get_block(block_number, state_trie) do
      {:ok, block} ->
        block_state = TrieStorage.set_root_hash(state_trie, block.header.state_root)

        case Account.get_account(block_state, address) do
          nil ->
            nil

          account ->
            Exth.encode_unsigned_hex(account.balance)
        end

      _ ->
        nil
    end
  end

  def get_transaction_by_hash(transaction_hash) do
    state_trie = get_last_sync_state().trie

    case Block.get_transaction_by_hash(transaction_hash, state_trie, true) do
      {transaction, block} -> ResponseTransaction.new(transaction, block)
      nil -> nil
    end
  end

  def get_transaction_receipt(transaction_hash) do
    state_trie = get_last_sync_state().trie

    case Block.get_receipt_by_transaction_hash(transaction_hash, state_trie) do
      {receipt, transaction, block} -> ResponseReceipt.new(receipt, transaction, block)
      nil -> nil
    end
  end

  def get_uncle_by_block_hash_and_index(block_hash, index) do
    trie = get_last_sync_state().trie

    case Block.get_block(block_hash, trie) do
      {:ok, block} ->
        case Enum.at(block.ommers, index) do
          nil ->
            nil

          ommer_header ->
            uncle_block = %Block{header: ommer_header, transactions: [], ommers: []}

            uncle_block
            |> Block.add_metadata(trie)
            |> ResponseBlock.new()
        end

      _ ->
        nil
    end
  end

  def get_uncle_by_block_number_and_index(block_number, index) do
    trie = get_last_sync_state().trie

    case Block.get_block(block_index, trie) do
      {:ok, block} ->
        case Enum.at(block.ommers, index) do
          nil ->
            nil

          ommer_header ->
            uncle_block = %Block{header: ommer_header, transactions: [], ommers: []}

            uncle_block
            |> Block.add_metadata(trie)
            |> ResponseBlock.new()
        end

      _ ->
        nil
    end
  end
end
