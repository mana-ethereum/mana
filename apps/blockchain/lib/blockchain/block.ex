defmodule Blockchain.Block do
  @moduledoc """
  This module effectively encodes a block, the heart of the blockchain.
  A chain is formed when blocks point to previous blocks,
  either as a parent or an ommer (uncle).
  For more information, see Section 4.3 of the Yellow Paper.
  """

  alias Block.Header
  alias Blockchain.BlockGetter
  alias Blockchain.BlockSetter
  alias Blockchain.{Account, Chain, Transaction}
  alias Blockchain.Account.Repo
  alias Blockchain.Block.HolisticValidity
  alias Blockchain.Transaction.Receipt
  alias Blockchain.Transaction.Receipt.Bloom
  alias ExthCrypto.Hash.Keccak
  alias MerklePatriciaTree.{DB, Trie}
  alias MerklePatriciaTree.TrieStorage

  # Defined in Eq.(19)
  # block_hash: Hash for this block, acts simply as a cache,
  # header: B_H,
  # transactions: B_T,
  # ommers: B_U
  # metadata: precomputated data required by JSON RPC spec
  defstruct block_hash: nil,
            header: %Header{},
            transactions: [],
            receipts: [],
            ommers: []

  @type t :: %__MODULE__{
          block_hash: EVM.hash() | nil,
          header: Header.t(),
          transactions: [Transaction.t()] | [],
          receipts: [Receipt.t()] | [],
          ommers: [Header.t()] | []
        }

  @block_reward_ommer_divisor 32
  @block_reward_ommer_offset 8

  @doc """
  Encodes a block such that it can be represented in RLP encoding.
  This is defined as `L_B` Eq.(35) in the Yellow Paper.

  ## Examples

    iex> Blockchain.Block.serialize(%Blockchain.Block{
    ...>   header: %Block.Header{parent_hash: <<1::256>>, ommers_hash: <<2::256>>, beneficiary: <<3::160>>, state_root: <<4::256>>, transactions_root: <<5::256>>, receipts_root: <<6::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<7::256>>, nonce: <<8::64>>},
    ...>   transactions: [%Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1::160>>, value: 8, v: 27, r: 9, s: 10, data: "hi"}],
    ...>   ommers: [%Block.Header{parent_hash: <<11::256>>, ommers_hash: <<12::256>>, beneficiary: <<13::160>>, state_root: <<14::256>>, transactions_root: <<15::256>>, receipts_root: <<16::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<17::256>>, nonce: <<18::64>>}]
    ...> })
    [
      [<<1::256>>, <<2::256>>, <<3::160>>, <<4::256>>, <<5::256>>, <<6::256>>, <<>>, 5, 1, 5, 3, 6, "Hi mom", <<7::256>>, <<8::64>>],
      [[<<5>>, <<6>>, <<7>>, <<1::160>>, <<8>>, "hi", <<27>>, <<9>>, <<10>>]],
      [[<<11::256>>, <<12::256>>, <<13::160>>, <<14::256>>, <<15::256>>, <<16::256>>, <<>>, 5, 1, 5, 3, 6, "Hi mom", <<17::256>>, <<18::64>>]]
    ]

    iex> Blockchain.Block.serialize(%Blockchain.Block{})
    [
      [
        nil,
        <<29, 204, 77, 232, 222, 199, 93, 122, 171, 133, 181, 103, 182, 204, 212, 26, 211, 18, 69, 27, 148, 138, 116, 19, 240, 161, 66, 253, 64, 212, 147, 71>>,
        nil,
        <<86, 232, 31, 23, 27, 204, 85, 166, 255, 131, 69, 230, 146, 192, 248, 110, 91, 72, 224, 27, 153, 108, 173, 192, 1, 98, 47, 181, 227, 99, 180, 33>>,
        <<86, 232, 31, 23, 27, 204, 85, 166, 255, 131, 69, 230, 146, 192, 248, 110, 91, 72, 224, 27, 153, 108, 173, 192, 1, 98, 47, 181, 227, 99, 180, 33>>,
        <<86, 232, 31, 23, 27, 204, 85, 166, 255, 131, 69, 230, 146, 192, 248, 110, 91, 72, 224, 27, 153, 108, 173, 192, 1, 98, 47, 181, 227, 99, 180, 33>>,
        <<0::2048>>,
        nil,
        nil,
        0,
        0,
        nil,
        "",
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
        <<0, 0, 0, 0, 0, 0, 0, 0>>
      ],
      [],
      []
    ]
  """
  @spec serialize(t) :: ExRLP.t()
  def serialize(block) do
    [
      # L_H(B_H)
      Header.serialize(block.header),
      # L_T(B_T)*
      Enum.map(block.transactions, &Transaction.serialize/1),
      # L_H(B_U)*
      Enum.map(block.ommers, &Header.serialize/1)
    ]
  end

  @doc """
  Decodes a block from an RLP encoding. Effectively inverts
  L_B defined in Eq.(35).

  ## Examples

      iex> Blockchain.Block.deserialize([
      ...>   [<<1::256>>, <<2::256>>, <<3::160>>, <<4::256>>, <<5::256>>, <<6::256>>, <<>>, <<5>>, <<1>>, <<5>>, <<3>>, <<6>>, "Hi mom", <<7::256>>, <<8::64>>],
      ...>   [[<<5>>, <<6>>, <<7>>, <<1::160>>, <<8>>, "hi", <<27>>, <<9>>, <<10>>]],
      ...>   [[<<11::256>>, <<12::256>>, <<13::160>>, <<14::256>>, <<15::256>>, <<16::256>>, <<>>, <<5>>, <<1>>, <<5>>, <<3>>, <<6>>, "Hi mom", <<17::256>>, <<18::64>>]]
      ...> ])
      %Blockchain.Block{
        header: %Block.Header{parent_hash: <<1::256>>, ommers_hash: <<2::256>>, beneficiary: <<3::160>>, state_root: <<4::256>>, transactions_root: <<5::256>>, receipts_root: <<6::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<7::256>>, nonce: <<8::64>>},
        transactions: [%Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1::160>>, value: 8, v: 27, r: 9, s: 10, data: "hi"}],
        ommers: [%Block.Header{parent_hash: <<11::256>>, ommers_hash: <<12::256>>, beneficiary: <<13::160>>, state_root: <<14::256>>, transactions_root: <<15::256>>, receipts_root: <<16::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<17::256>>, nonce: <<18::64>>}]
      }
  """
  @spec deserialize(ExRLP.t()) :: t
  def deserialize(rlp) do
    [
      header,
      transactions,
      ommers
    ] = rlp

    %__MODULE__{
      header: Header.deserialize(header),
      transactions: Enum.map(transactions, &Transaction.deserialize/1),
      ommers: Enum.map(ommers, &Header.deserialize/1)
    }
  end

  @spec decode_rlp(binary()) :: {:ok, [ExRLP.t()]} | {:error, any()}
  def decode_rlp("0x" <> hex_data) do
    hex_binary = Base.decode16!(hex_data, case: :mixed)

    decode_rlp(hex_binary)
  rescue
    e ->
      {:error, e}
  end

  def decode_rlp(rlp) when is_binary(rlp) do
    rlp |> ExRLP.decode() |> decode_rlp()
  rescue
    e ->
      {:error, e}
  end

  def decode_rlp(rlp_result_list) do
    {:ok, deserialize(rlp_result_list)}
  rescue
    e ->
      {:error, e}
  end

  @doc """
  Computes hash of a block, which is simply the hash of the serialized
  block after applying RLP encoding.

  This is defined in Eq.(37) of the Yellow Paper.

  ## Examples

      iex> %Blockchain.Block{header: %Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}}
      ...> |> Blockchain.Block.hash()
      <<78, 28, 127, 10, 192, 253, 127, 239, 254, 179, 39, 34, 245, 44, 152, 98, 128, 71, 238, 155, 100, 161, 199, 71, 243, 223, 172, 191, 74, 99, 128, 63>>

      iex> %Blockchain.Block{header: %Block.Header{number: 0, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}}
      ...> |> Blockchain.Block.hash()
      <<218, 225, 46, 241, 196, 160, 136, 96, 109, 216, 73, 167, 92, 174, 91, 228, 85, 112, 234, 129, 99, 200, 158, 61, 223, 166, 165, 132, 187, 24, 142, 193>>
  """
  @spec hash(t) :: EVM.hash()
  def hash(block), do: Header.hash(block.header)

  @doc """
  Fetches the block hash for a block, either by calculating the block hash
  based on the block data, or returning the block hash from the block's struct.

  ## Examples

      iex> %Blockchain.Block{header: %Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}}
      ...> |> Blockchain.Block.fetch_block_hash()
      <<78, 28, 127, 10, 192, 253, 127, 239, 254, 179, 39, 34, 245, 44, 152, 98, 128, 71, 238, 155, 100, 161, 199, 71, 243, 223, 172, 191, 74, 99, 128, 63>>

      iex> %Blockchain.Block{block_hash: <<5::256>>, header: %Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}}
      ...> |> Blockchain.Block.fetch_block_hash()
      <<5::256>>
  """
  @spec fetch_block_hash(t()) :: EVM.hash()
  def fetch_block_hash(block) do
    case block.block_hash do
      nil -> hash(block)
      block_hash -> block_hash
    end
  end

  @doc """
  If a block already has a hash, returns the same unchanged, but if the block
  hash has not yet been calculated, returns the block with the block hash
  stored in the struct.

  ## Examples

      iex> %Blockchain.Block{header: %Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}}
      ...> |> Blockchain.Block.with_hash()
      %Blockchain.Block{
        block_hash: <<78, 28, 127, 10, 192, 253, 127, 239, 254, 179, 39, 34, 245, 44, 152, 98, 128, 71, 238, 155, 100, 161, 199, 71, 243, 223, 172, 191, 74, 99, 128, 63>>,
        header: %Block.Header{
          number: 5,
          parent_hash: <<1, 2, 3>>,
          beneficiary: <<2, 3, 4>>,
          difficulty: 100,
          timestamp: 11,
          mix_hash: <<1>>,
          nonce: <<2>>
        }
      }

      iex> %Blockchain.Block{block_hash: <<5::256>>, header: %Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}}
      ...> |> Blockchain.Block.with_hash()
      %Blockchain.Block{
        block_hash: <<5::256>>,
        header: %Block.Header{
          number: 5,
          parent_hash: <<1, 2, 3>>,
          beneficiary: <<2, 3, 4>>,
          difficulty: 100,
          timestamp: 11,
          mix_hash: <<1>>,
          nonce: <<2>>
        }
      }
  """
  @spec with_hash(t()) :: t()
  def with_hash(block) do
    %{block | block_hash: fetch_block_hash(block)}
  end

  @doc """
  Stores a given block in the database and returns the block hash.

  This should be used if we ever want to retrieve that block in
  the future.

  Note: Blocks are identified by a hash of the block header,
        thus we will only get the same block back if the header
        matches what we stored.

  ## Examples

      iex> trie = MerklePatriciaTree.Test.random_ets_db() |> MerklePatriciaTree.Trie.new()
      iex> block = %Blockchain.Block{header: %Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}}
      iex> {:ok, {hash, _}} = Blockchain.Block.put_block(block, trie)
      iex> hash
      <<78, 28, 127, 10, 192, 253, 127, 239, 254, 179, 39, 34, 245, 44, 152, 98, 128, 71, 238, 155, 100, 161, 199, 71, 243, 223, 172, 191, 74, 99, 128, 63>>
  """
  @spec put_block(t, TrieStorage.t(), binary() | nil) :: {:ok, {EVM.hash(), TrieStorage.t()}}
  def put_block(block, trie, precomputated_hash \\ nil) do
    block_with_metadata = add_metadata(block, trie, precomputated_hash)
    block_hash = block_with_metadata.block_hash

    block_bin = :erlang.term_to_binary(block_with_metadata)

    updated_trie =
      trie
      |> TrieStorage.put_raw_key!(block_hash, block_bin)
      |> TrieStorage.put_raw_key!(
        block_hash_key(block.header.number),
        block_hash
      )

    {:ok, {block_hash, updated_trie}}
  end

  @doc """
  Returns a given block from the database, if the hash
  exists in the database.

  See `Blockchain.Block.put_block/2` for details.
  """
  @spec get_block(EVM.hash(), TrieStorage.t()) :: {:ok, t} | :not_found
  def get_block(block_hash, trie) do
    with {:ok, block_bin} <- TrieStorage.get_raw_key(trie, block_hash) do
      block = :erlang.binary_to_term(block_bin)

      {:ok, block}
    end
  end

  @doc """
  Returns the specified block from the database if it's hash is found by the provided block_number, otherwise :not_found.
  """
  @spec get_block_by_number(integer(), TrieStorage.t()) :: {:ok, t} | :not_found
  def get_block_by_number(block_number, trie) do
    with {:ok, hash} <- get_block_hash_by_number(trie, block_number) do
      get_block(hash, trie)
    end
  end

  @spec block_hash_key(integer()) :: String.t()
  defp block_hash_key(number) do
    "hash_for_#{number}"
  end

  @doc """

  Returns the parent node for a given block, if it exists.
  We assume a block is a genesis block if it does not have
  a valid `parent_hash` set.

  ## Examples

      iex> Blockchain.Block.get_parent_block(%Blockchain.Block{header: %Block.Header{number: 0}}, nil)
      :genesis

      iex> trie = MerklePatriciaTree.Test.random_ets_db() |> MerklePatriciaTree.Trie.new()
      iex> block = %Blockchain.Block{header: %Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}}
      iex> Blockchain.Block.put_block(block, trie)
      iex> Blockchain.Block.get_parent_block(%Blockchain.Block{header: %Block.Header{parent_hash: block |> Blockchain.Block.hash}}, trie)
      {:ok, %Blockchain.Block{block_hash: <<78, 28, 127, 10, 192, 253, 127, 239, 254, 179, 39, 34, 245, 44, 152, 98, 128, 71, 238, 155, 100, 161, 199, 71, 243, 223, 172, 191, 74, 99, 128, 63>>, header: %Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>, size: 415, total_difficulty: 100}}}

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> block = %Blockchain.Block{header: %Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}}
      iex> Blockchain.Block.get_parent_block(%Blockchain.Block{header: %Block.Header{parent_hash: block |> Blockchain.Block.hash}}, MerklePatriciaTree.Trie.new(db))
      :not_found
  """
  @spec get_parent_block(t, TrieStorage.t()) :: {:ok, t} | :genesis | :not_found
  def get_parent_block(block, trie) do
    case block.header.number do
      0 -> :genesis
      _ -> get_block(block.header.parent_hash, trie)
    end
  end

  @doc """
  Returns the total number of transactions
  included in a block. This is based on the
  transaction list for a given block.

  ## Examples

      iex> Blockchain.Block.get_transaction_count(%Blockchain.Block{transactions: [%Blockchain.Transaction{}, %Blockchain.Transaction{}]})
      2
  """
  @spec get_transaction_count(t) :: integer()
  def get_transaction_count(block), do: Enum.count(block.transactions)

  @doc """
  Returns a given receipt from a block. This is
  based on the receipts root where all receipts
  are stored for the given block.

  ## Examples

      iex> trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      iex> {updated_block, _new_trie} = Blockchain.Block.put_receipt(%Blockchain.Block{}, 6, %Blockchain.Transaction.Receipt{state: <<1, 2, 3>>, cumulative_gas: 10, bloom_filter: <<2, 3, 4>>, logs: []}, trie)
      iex> {updated_block, _new_trie} = Blockchain.Block.put_receipt(updated_block, 7, %Blockchain.Transaction.Receipt{state: <<4, 5, 6>>, cumulative_gas: 11, bloom_filter: <<5, 6, 7>>, logs: []}, trie)
      iex> Blockchain.Block.get_receipt(updated_block, 6, trie.db)
      %Blockchain.Transaction.Receipt{state: <<1, 2, 3>>, cumulative_gas: 10, bloom_filter: <<2, 3, 4>>, logs: []}

      iex> trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      iex> {new_block, new_trie} = Blockchain.Block.put_receipt(%Blockchain.Block{}, 6, %Blockchain.Transaction.Receipt{state: <<1, 2, 3>>, cumulative_gas: 10, bloom_filter: <<2, 3, 4>>, logs: []}, trie)
      iex> Blockchain.Block.get_receipt(new_block, 7, new_trie.db)
      nil
  """
  @spec get_receipt(t, integer(), DB.db()) :: Receipt.t() | nil
  def get_receipt(block, i, db) do
    serialized_receipt =
      db
      |> Trie.new(block.header.receipts_root)
      |> Trie.get_key(i |> ExRLP.encode())

    case serialized_receipt do
      nil ->
        nil

      _ ->
        serialized_receipt
        |> ExRLP.decode()
        |> Receipt.deserialize()
    end
  end

  @doc """
  Returns a given transaction from a block. This is
  based on the transactions root where all transactions
  are stored for the given block.
  """
  @spec get_transaction(t, integer(), DB.db()) :: Transaction.t() | nil
  def get_transaction(block, i, db) do
    encoded_transaction_number = ExRLP.encode(i)

    serialized_transaction =
      db
      |> Trie.new(block.header.transactions_root)
      |> Trie.get_key(encoded_transaction_number)

    case serialized_transaction do
      nil ->
        nil

      _ ->
        serialized_transaction
        |> ExRLP.decode()
        |> Transaction.deserialize()
    end
  end

  @doc """
  Returns the cumulative gas used by a block based on the
  listed transactions. This is defined in largely in the
  note after Eq.(66) referenced as l(B_R)_u, or the last
  receipt's cumulative gas.

  The receipts aren't directly included in the block, so
  we'll need to pull it from the receipts root.

  Note: this will case if we do not have a receipt for
  the most recent transaction.

  ## Examples

      iex> trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      iex> {updated_block, new_trie} = %Blockchain.Block{transactions: [1,2,3,4,5,6,7]}
      ...> |> Blockchain.Block.put_receipt(6, %Blockchain.Transaction.Receipt{state: <<1, 2, 3>>, cumulative_gas: 10, bloom_filter: <<2, 3, 4>>, logs: []}, trie)
      iex> {updated_block, new_trie} =  Blockchain.Block.put_receipt(updated_block, 7, %Blockchain.Transaction.Receipt{state: <<4, 5, 6>>, cumulative_gas: 11, bloom_filter: <<5, 6, 7>>, logs: []}, new_trie)
      iex> Blockchain.Block.get_cumulative_gas(updated_block, new_trie.db)
      11

      iex> trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      iex> {updated_block, new_trie} = %Blockchain.Block{transactions: [1,2,3,4,5,6]}
      ...> |> Blockchain.Block.put_receipt(6, %Blockchain.Transaction.Receipt{state: <<1, 2, 3>>, cumulative_gas: 10, bloom_filter: <<2, 3, 4>>, logs: []}, trie)
      iex> {updated_block, _new_trie} = Blockchain.Block.put_receipt(updated_block, 7, %Blockchain.Transaction.Receipt{state: <<4, 5, 6>>, cumulative_gas: 11, bloom_filter: <<5, 6, 7>>, logs: []}, new_trie)
      ...> Blockchain.Block.get_cumulative_gas(updated_block, trie.db)
      10

      iex> trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      iex> %Blockchain.Block{}
      ...> |> Blockchain.Block.get_cumulative_gas(trie.db)
      0

      iex> trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      iex> {updated_block, new_trie} = %Blockchain.Block{transactions: [1,2,3,4,5,6,7,8]}
      ...> |> Blockchain.Block.put_receipt(6, %Blockchain.Transaction.Receipt{state: <<1, 2, 3>>, cumulative_gas: 10, bloom_filter: <<2, 3, 4>>, logs: []}, trie)
      iex> {updated_block, _new_trie} = Blockchain.Block.put_receipt(updated_block, 7, %Blockchain.Transaction.Receipt{state: <<4, 5, 6>>, cumulative_gas: 11, bloom_filter: <<5, 6, 7>>, logs: []}, new_trie)
      iex> Blockchain.Block.get_cumulative_gas(updated_block, trie.db)
      ** (RuntimeError) cannot find receipt
  """
  @spec get_cumulative_gas(t, atom()) :: EVM.Gas.t()
  def get_cumulative_gas(block = %__MODULE__{}, db) do
    case get_transaction_count(block) do
      0 ->
        0

      i ->
        case get_receipt(block, i, db) do
          nil -> raise "cannot find receipt"
          receipt -> receipt.cumulative_gas
        end
    end
  end

  @doc """
  Creates a new block from a parent block. This will handle setting
  the block number, the difficulty and will keep the `gas_limit` the
  same as the parent's block unless specified in `opts`.

  A timestamp is required for difficulty calculation.
  If it's not specified, it will default to the current system time.

  This function is not directly addressed in the Yellow Paper.

  ## Examples

      iex> %Blockchain.Block{header: %Block.Header{parent_hash: <<0::256>>, beneficiary: <<5::160>>, state_root: <<1::256>>, number: 100_000, difficulty: 15_500_0000, timestamp: 5_000_000, gas_limit: 500_000}}
      ...> |> Blockchain.Block.gen_child_block(Blockchain.Test.ropsten_chain(), timestamp: 5010000, extra_data: "hi", beneficiary: <<5::160>>)
      %Blockchain.Block{
        header: %Block.Header{
          state_root: <<1::256>>,
          beneficiary: <<5::160>>,
          number: 100_001,
          difficulty: 147_507_383,
          timestamp: 5_010_000,
          gas_limit: 500_000,
          extra_data: "hi",
          parent_hash: <<141, 203, 173, 190, 43, 64, 71, 106, 211, 77, 254, 89, 58, 72, 3, 108, 6, 101, 232, 254, 10, 149, 244, 245, 102, 5, 55, 235, 198, 39, 66, 227>>
        }
      }

      iex> %Blockchain.Block{header: %Block.Header{parent_hash: <<0::256>>, beneficiary: <<5::160>>, state_root: <<1::256>>, number: 100_000, difficulty: 1_500_0000, timestamp: 5000, gas_limit: 500_000}}
      ...> |> Blockchain.Block.gen_child_block(Blockchain.Test.ropsten_chain(), state_root: <<2::256>>, timestamp: 6010, extra_data: "hi", beneficiary: <<5::160>>)
      %Blockchain.Block{
        header: %Block.Header{
          state_root: <<2::256>>,
          beneficiary: <<5::160>>,
          number: 100_001,
          difficulty: 142_74_924,
          timestamp: 6010,
          gas_limit: 500_000,
          extra_data: "hi",
          parent_hash: <<233, 151, 241, 216, 121, 36, 187, 39, 42, 93, 8, 68, 162, 118, 84, 219, 140, 35, 220, 90, 118, 129, 76, 45, 249, 55, 241, 82, 181, 30, 22, 128>>
        }
      }
  """
  @spec gen_child_block(t, Chain.t(), keyword()) :: t
  def gen_child_block(parent_block, chain, opts \\ []) do
    gas_limit = get_opts_property(opts, :gas_limit, parent_block.header.gas_limit)

    header = gen_child_header(parent_block, opts)

    %__MODULE__{header: header}
    |> BlockSetter.set_block_number(parent_block)
    |> BlockSetter.set_block_difficulty(chain, parent_block)
    |> BlockSetter.set_block_gas_limit(chain, parent_block, gas_limit)
    |> BlockSetter.set_block_parent_hash(parent_block)
  end

  @spec gen_child_header(t, keyword()) :: Header.t()
  defp gen_child_header(parent_block, opts) do
    timestamp = get_opts_property(opts, :timestamp, System.system_time(:second))
    beneficiary = get_opts_property(opts, :beneficiary, nil)
    extra_data = get_opts_property(opts, :extra_data, <<>>)
    state_root = get_opts_property(opts, :state_root, parent_block.header.state_root)
    mix_hash = get_opts_property(opts, :mix_hash, parent_block.header.mix_hash)

    %Header{
      state_root: state_root,
      timestamp: timestamp,
      extra_data: extra_data,
      beneficiary: beneficiary,
      mix_hash: mix_hash
    }
  end

  @doc """
  Attaches an ommer to a block. We do no validation at this stage.

  ## Examples

      iex> Blockchain.Block.add_ommers(%Blockchain.Block{}, [%Block.Header{parent_hash: <<1::256>>, ommers_hash: <<2::256>>, beneficiary: <<3::160>>, state_root: <<4::256>>, transactions_root: <<5::256>>, receipts_root: <<6::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<7::256>>, nonce: <<8::64>>}])
      %Blockchain.Block{
        ommers: [
          %Block.Header{parent_hash: <<1::256>>, ommers_hash: <<2::256>>, beneficiary: <<3::160>>, state_root: <<4::256>>, transactions_root: <<5::256>>, receipts_root: <<6::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<7::256>>, nonce: <<8::64>>}
        ],
        header: %Block.Header{
          ommers_hash: <<59, 196, 156, 242, 196, 38, 21, 97, 112, 6, 73, 111, 12, 88, 35, 155, 72, 175, 82, 0, 163, 128, 115, 236, 45, 99, 88, 62, 88, 80, 122, 96>>
        }
      }
  """
  @spec add_ommers(t, [Header.t()]) :: t
  def add_ommers(block, ommers) do
    total_ommers = block.ommers ++ ommers
    serialized_ommers_list = Enum.map(total_ommers, &Block.Header.serialize/1)
    new_ommers_hash = serialized_ommers_list |> ExRLP.encode() |> Keccak.kec()

    %{block | ommers: total_ommers, header: %{block.header | ommers_hash: new_ommers_hash}}
  end

  @doc """
  Gets an ommer for a given block, based on the ommers_hash.

  ## Examples

      iex> %Blockchain.Block{}
      ...> |> Blockchain.Block.add_ommers([%Block.Header{parent_hash: <<1::256>>, ommers_hash: <<2::256>>, beneficiary: <<3::160>>, state_root: <<4::256>>, transactions_root: <<5::256>>, receipts_root: <<6::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<7::256>>, nonce: <<8::64>>}])
      ...> |> Blockchain.Block.get_ommer(0)
      %Block.Header{parent_hash: <<1::256>>, ommers_hash: <<2::256>>, beneficiary: <<3::160>>, state_root: <<4::256>>, transactions_root: <<5::256>>, receipts_root: <<6::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<7::256>>, nonce: <<8::64>>}
  """
  @spec get_ommer(t, integer()) :: Header.t()
  def get_ommer(block, i) do
    Enum.at(block.ommers, i)
  end

  @doc """
  Checks the validity of a block, including the validity of the
  header and the transactions. This should verify that we should
  accept the authenticity of a block.

  ## Examples

      iex> trie = MerklePatriciaTree.Test.random_ets_db() |> MerklePatriciaTree.Trie.new()
      iex> chain = Blockchain.Test.ropsten_chain()
      iex> {updated_block, _new_trie} = Blockchain.Genesis.create_block(chain, trie)
      iex> {updated_block, _new_trie} =  Blockchain.Block.add_rewards(updated_block, trie, chain)
      iex> {status, _} = Blockchain.Block.validate(updated_block, chain, nil, trie)
      iex> status
      :valid

      iex> trie = MerklePatriciaTree.Test.random_ets_db() |> MerklePatriciaTree.Trie.new()
      iex> chain = Blockchain.Test.ropsten_chain()
      iex> {parent, _} = Blockchain.Genesis.create_block(chain, trie)
      iex> child = Blockchain.Block.gen_child_block(parent, chain)
      iex> Blockchain.Block.validate(child, chain, :parent_not_found, trie)
      {:invalid, [:non_genesis_block_requires_parent]}

      iex> trie = MerklePatriciaTree.Test.random_ets_db() |> MerklePatriciaTree.Trie.new()
      iex> chain = Blockchain.Test.ropsten_chain()
      iex> {parent, _} = Blockchain.Genesis.create_block(chain, trie)
      iex> beneficiary = <<0x05::160>>
      iex> {child, _} = Blockchain.Block.gen_child_block(parent, chain, beneficiary: beneficiary)
      ...> |> Blockchain.Block.add_rewards(trie, chain)
      iex> {status, _} = Blockchain.Block.validate(child, chain, parent, trie)
      iex> status
      :valid
  """
  @spec validate(t, Chain.t(), t, TrieStorage.t()) ::
          {:valid, TrieStorage.t()} | {:invalid, [atom()]}
  def validate(block, chain, parent_block, db) do
    with :valid <- validate_parent_block(block, parent_block),
         :valid <- validate_header(block, parent_block, chain) do
      HolisticValidity.validate(block, chain, parent_block, db)
    end
  end

  defp validate_header(block, parent_block, chain) do
    expected_difficulty = BlockGetter.get_difficulty(block, parent_block, chain)
    parent_block_header = if parent_block, do: parent_block.header, else: nil

    validate_dao_extra_data =
      Chain.support_dao_fork?(chain) &&
        Chain.within_dao_fork_extra_range?(chain, block.header.number)

    Header.validate(
      block.header,
      parent_block_header,
      expected_difficulty,
      chain.params[:gas_limit_bound_divisor],
      chain.params[:min_gas_limit],
      validate_dao_extra_data
    )
  end

  defp validate_parent_block(block, parent_block) do
    if block.header.number > 0 and parent_block == :parent_not_found do
      {:invalid, [:non_genesis_block_requires_parent]}
    else
      :valid
    end
  end

  @doc """
  For a given block, this will add the given transactions to its
  list of transaction and update the header state accordingly. That
  is, we will execute each transaction and update the state root,
  transaction receipts, etc. We effectively implement Eq.(2), Eq.(3)
  and Eq.(4) of the Yellow Paper, referred to as Π.

  The trie db refers to where we expect our trie to exist, e.g.
  in `:ets` or `:rocksdb`. See `MerklePatriciaTree.DB`.
  """
  @spec add_transactions(t, [Transaction.t()], DB.db(), Chain.t()) :: t
  def add_transactions(block, transactions, trie, chain) do
    {updated_block, updated_trie} = process_hardfork_specifics(block, chain, trie)

    {updated_block, updated_trie} =
      do_add_transactions(updated_block, transactions, updated_trie, chain)

    updated_block = calculate_logs_bloom(updated_block)

    {updated_block, updated_trie}
  end

  defp process_hardfork_specifics(block, chain, trie) do
    if Chain.support_dao_fork?(chain) && Chain.dao_fork?(chain, block.header.number) do
      repo =
        trie
        |> TrieStorage.set_root_hash(block.header.state_root)
        |> Account.Repo.new()
        |> Blockchain.Hardfork.Dao.execute(chain)

      updated_block = put_state(block, repo.state)
      {updated_block, repo.state}
    else
      {block, trie}
    end
  end

  @spec do_add_transactions(t, [Transaction.t()], DB.db(), Chain.t(), integer()) ::
          {t, TrieStorage.t()}
  defp do_add_transactions(block, transactions, state, chain, trx_count \\ 0)

  defp do_add_transactions(block, [], trie, _, _), do: {block, trie}

  defp do_add_transactions(
         block = %__MODULE__{header: header},
         [trx | transactions],
         trie,
         chain,
         trx_count
       ) do
    state = TrieStorage.set_root_hash(trie, header.state_root)

    {new_account_repo, gas_used, receipt} =
      Transaction.execute_with_validation(state, trx, header, chain)

    new_state = Repo.commit(new_account_repo).state

    total_gas_used = block.header.gas_used + gas_used
    receipt = %{receipt | cumulative_gas: total_gas_used}

    updated_block =
      block
      |> put_state(new_state)
      |> put_gas_used(total_gas_used)

    {updated_block, updated_state} = put_receipt(updated_block, trx_count, receipt, new_state)
    {updated_block, updated_state} = put_transaction(updated_block, trx_count, trx, updated_state)

    do_add_transactions(updated_block, transactions, updated_state, chain, trx_count + 1)
  end

  @spec calculate_logs_bloom(t()) :: t()
  defp calculate_logs_bloom(block) do
    logs_bloom = Bloom.from_receipts(block.receipts)

    updated_header = %{block.header | logs_bloom: logs_bloom}

    %{block | header: updated_header}
  end

  # Updates a block to have a new state root given a state object
  @spec put_state(t, Trie.t()) :: t
  def put_state(block = %__MODULE__{header: header = %Header{}}, new_state) do
    root_hash = TrieStorage.root_hash(new_state)

    %{block | header: %{header | state_root: root_hash}}
  end

  # Updates a block to have total gas used set in the header
  @spec put_gas_used(t, EVM.Gas.t()) :: t
  def put_gas_used(block = %__MODULE__{header: header}, gas_used) do
    %{block | header: %{header | gas_used: gas_used}}
  end

  @doc """
  Updates a block by adding a receipt to the list of receipts
  at position `i`.

  ## Examples

      iex> trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      iex> {block, _} = Blockchain.Block.put_receipt(%Blockchain.Block{}, 5, %Blockchain.Transaction.Receipt{state: <<1, 2, 3>>, cumulative_gas: 10, bloom_filter: <<2, 3, 4>>, logs: "hi mom"}, trie)
      iex> MerklePatriciaTree.Trie.into(block.header.receipts_root, trie)
      ...> |> MerklePatriciaTree.Trie.Inspector.all_values()
      [{<<5>>, <<208, 131, 1, 2, 3, 10, 131, 2, 3, 4, 134, 104, 105, 32, 109, 111, 109>>}]
  """
  @spec put_receipt(t, integer(), Receipt.t(), TrieStorage.t()) :: {t, TrieStorage.t()}
  def put_receipt(block, i, receipt, trie) do
    encoded_receipt = receipt |> Receipt.serialize() |> ExRLP.encode()

    {subtrie, updated_trie} =
      TrieStorage.update_subtrie_key(
        trie,
        block.header.receipts_root,
        ExRLP.encode(i),
        encoded_receipt
      )

    updated_receipts_root = TrieStorage.root_hash(subtrie)

    updated_header = %{block.header | receipts_root: updated_receipts_root}
    updated_receipts = block.receipts ++ [receipt]

    {%{block | header: updated_header, receipts: updated_receipts}, updated_trie}
  end

  @doc """
  Updates a block by adding a transaction to the list of transactions
  and updating the transactions_root in the header at position `i`, which
  should be equilvant to the current number of transactions.

  ## Examples

      iex> trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      iex> {block, _new_trie} = Blockchain.Block.put_transaction(%Blockchain.Block{}, 0, %Blockchain.Transaction{nonce: 1, v: 2, r: 3, s: 4}, trie)
      iex> block.transactions
      [%Blockchain.Transaction{nonce: 1, v: 2, r: 3, s: 4}]
      iex> MerklePatriciaTree.Trie.into(block.header.transactions_root, trie)
      ...> |> MerklePatriciaTree.Trie.Inspector.all_values()
      [{<<0x80>>, <<201, 1, 128, 128, 128, 128, 128, 2, 3, 4>>}]
  """
  @spec put_transaction(t, integer(), Transaction.t(), TrieStorage.t()) :: {t, TrieStorage.t()}
  def put_transaction(block, i, trx, trie) do
    total_transactions = block.transactions ++ [trx]
    encoded_transaction = trx |> Transaction.serialize() |> ExRLP.encode()

    {subtrie, updated_trie} =
      TrieStorage.update_subtrie_key(
        trie,
        block.header.transactions_root,
        ExRLP.encode(i),
        encoded_transaction
      )

    updated_transactions_root = TrieStorage.root_hash(subtrie)

    {%{
       block
       | transactions: total_transactions,
         header: %{block.header | transactions_root: updated_transactions_root}
     }, updated_trie}
  end

  @doc """
  Adds the rewards to miners (including for ommers) to a block.
  This is defined in Section 11.3, Eq.(159-163) of the Yellow Paper.

  ## Examples

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> miner = <<0x05::160>>
      iex> chain = Blockchain.Test.ropsten_chain()
      iex> state = MerklePatriciaTree.Trie.new(db)
      ...>         |> Blockchain.Account.put_account(miner, %Blockchain.Account{balance: 400_000})
      iex> block = %Blockchain.Block{header: %Block.Header{number: 0, state_root: state.root_hash, beneficiary: miner}}
      iex> {updated_block, _new_trie} =
      ...> block
      ...> |> Blockchain.Block.add_rewards(MerklePatriciaTree.Trie.new(db), chain)
      iex> updated_block
      ...> |> Blockchain.BlockGetter.get_state(MerklePatriciaTree.Trie.new(db))
      ...> |> Blockchain.Account.get_accounts([miner])
      [%Blockchain.Account{balance: 400_000}]

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> miner = <<0x05::160>>
      iex> chain = Blockchain.Test.ropsten_chain()
      iex> state = MerklePatriciaTree.Trie.new(db)
      ...>         |> Blockchain.Account.put_account(miner, %Blockchain.Account{balance: 400_000})
      iex> block = %Blockchain.Block{header: %Block.Header{state_root: state.root_hash, beneficiary: miner}}
      iex> {updated_block, updated_trie} = Blockchain.Block.add_rewards(block, state, chain)
      iex> updated_block
      ...> |> Blockchain.BlockGetter.get_state(updated_trie)
      ...> |> Blockchain.Account.get_accounts([miner])
      [%Blockchain.Account{balance: 2000000000000400000}]
  """
  @spec add_rewards(t, TrieStorage.t(), Chain.t()) :: {t, TrieStorage.t()}
  def add_rewards(block, trie, chain)

  def add_rewards(%{header: %{beneficiary: beneficiary}}, _trie, _chain)
      when is_nil(beneficiary),
      do: raise("Unable to add block rewards, beneficiary is nil")

  def add_rewards(block = %{header: %{number: number}}, trie, _chain)
      when number == 0,
      do: {block, trie}

  def add_rewards(block, trie, chain) do
    base_reward = Chain.block_reward_for_block(chain, block.header.number)

    state =
      block
      |> BlockGetter.get_state(trie)
      |> add_miner_reward(block, base_reward)
      |> add_ommer_rewards(block, base_reward)

    updated_block = BlockSetter.set_state(block, state)

    {updated_block, state}
  end

  defp add_miner_reward(state, block, base_reward) do
    ommer_reward = round(base_reward * length(block.ommers) / @block_reward_ommer_divisor)
    reward = ommer_reward + base_reward

    Account.add_wei(state, block.header.beneficiary, reward)
  end

  defp add_ommer_rewards(state, block, base_reward) do
    Enum.reduce(block.ommers, state, fn ommer, state ->
      height_difference = block.header.number - ommer.number

      reward =
        round(
          (@block_reward_ommer_offset - height_difference) *
            (base_reward / @block_reward_ommer_offset)
        )

      Account.add_wei(state, ommer.beneficiary, reward)
    end)
  end

  defp get_block_hash_by_number(trie, block_number) do
    TrieStorage.get_raw_key(trie, block_hash_key(block_number))
  end

  defp get_opts_property(opts, property, default) do
    case Keyword.get(opts, property, nil) do
      nil -> default
      property_value -> property_value
    end
  end

  defp add_metadata(block, trie, predefined_hash) do
    block_rlp_size =
      block
      |> serialize
      |> ExRLP.encode()
      |> byte_size()

    total_difficulty =
      case get_block(block.header.parent_hash, trie) do
        {:ok, parent_block} ->
          parent_block.header.total_difficulty + block.header.difficulty

        _ ->
          block.header.difficulty
      end

    hash = if predefined_hash, do: predefined_hash, else: hash(block)

    updated_block = %{block.header | size: block_rlp_size, total_difficulty: total_difficulty}

    %{block | block_hash: hash, header: updated_block}
  end
end
