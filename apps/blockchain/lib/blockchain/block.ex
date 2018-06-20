defmodule Blockchain.Block do
  @moduledoc """
  This module effectively encodes a Block, the heart of the blockchain.
  A chain is formed when blocks point to previous blocks,
  either as a parent or an ommer (uncle).
  For more information, see Section 4.3 of the Yellow Paper.
  """

  alias ExthCrypto.Hash.Keccak
  alias EthCore.Block.Header
  alias EthCore.Block.Header.Difficulty
  alias Blockchain.{Account, Transaction, Chain}
  alias Blockchain.Block.HolisticValidity
  alias Blockchain.Transaction.Receipt
  alias MerklePatriciaTree.{Trie, DB}

  # Defined in Eq.(19)
  # block_hash: Hash for this block, acts simply as a cache,
  # header: B_H,
  # transactions: B_T,
  # ommers: B_U
  defstruct block_hash: nil,
            header: %Header{},
            transactions: [],
            ommers: []

  @type t :: %__MODULE__{
          block_hash: EVM.hash() | nil,
          header: Header.t(),
          transactions: [Transaction.t()],
          ommers: [Header.t()]
        }

  # R_b in Eq.(164)
  @reward_wei round(5.0e18)

  @doc """
  Encodes a block such that it can be represented in RLP encoding.
  This is defined as `L_B` Eq.(35) in the Yellow Paper.
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
  Decodes a block from an RLP encoding.
  Effectively inverts L_B defined in Eq.(35).
  """
  @spec deserialize(ExRLP.t()) :: t
  def deserialize(rlp) do
    [header, transactions, ommers] = rlp

    %__MODULE__{
      header: Header.deserialize(header),
      transactions: Enum.map(transactions, &Transaction.deserialize/1),
      ommers: Enum.map(ommers, &Header.deserialize/1)
    }
  end

  @doc """
  Computes hash of a block (header).
  This is defined in Eq.(33) of the Yellow Paper.
  """
  @spec hash(t) :: EVM.hash()
  def hash(block), do: Header.hash(block.header)

  @doc """
  Stores a given block in the database and returns the block hash.
  This should be used if we ever want to retrieve that block in the future.

  Note: Blocks are identified by a hash of the block header,
        thus we will only get the same block back if the header
        matches what we stored.

  ## Examples

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> block = %Blockchain.Block{header: %EthCore.Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}}
      iex> Blockchain.Block.put_block(block, db)
      {:ok, <<78, 28, 127, 10, 192, 253, 127, 239, 254, 179, 39, 34, 245, 44, 152, 98, 128, 71, 238, 155, 100, 161, 199, 71, 243, 223, 172, 191, 74, 99, 128, 63>>}
      iex> {:ok, serialized_block} = MerklePatriciaTree.DB.get(db, block |> Blockchain.Block.hash)
      iex> serialized_block |> ExRLP.decode |> Blockchain.Block.deserialize()
      %Blockchain.Block{header: %EthCore.Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}}
  """
  @spec put_block(t, DB.db()) :: {:ok, EVM.hash()}
  def put_block(block, db) do
    hash = hash(block)
    block_rlp = block |> serialize |> ExRLP.encode()
    :ok = MerklePatriciaTree.DB.put!(db, hash, block_rlp)

    {:ok, hash}
  end

  @doc """
  Returns a given block from the database, if the hash
  exists in the database.

  See `Blockchain.Block.put_block/2` for details.

  ## Examples

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> Blockchain.Block.get_block(<<1, 2, 3>>, db)
      :not_found

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> block = %Blockchain.Block{
      ...>   transactions: [%Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1::160>>, value: 8, v: 27, r: 9, s: 10, data: "hi"}],
      ...>   header: %EthCore.Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}
      ...> }
      iex> Blockchain.Block.put_block(block, db)
      iex> Blockchain.Block.get_block(block |> Blockchain.Block.hash, db)
      {:ok, %Blockchain.Block{
        transactions: [%Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1::160>>, value: 8, v: 27, r: 9, s: 10, data: "hi"}],
        header: %EthCore.Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}
      }}
  """
  @spec get_block(EVM.hash(), DB.db()) :: {:ok, t} | :not_found
  def get_block(block_hash, db) do
    with {:ok, rlp} <- MerklePatriciaTree.DB.get(db, block_hash) do
      block = rlp |> ExRLP.decode() |> deserialize()
      {:ok, block}
    end
  end

  @doc """
  Gets a parent of the given block, if the hash exists in the database.
  Returns the given block itself, if `step` is equal to 0.

  See `Blockchain.Block.put_block/2` for details.

  ## Examples

      # Legit, current block
      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> block = %Blockchain.Block{
      ...>   transactions: [%Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1::160>>, value: 8, v: 27, r: 9, s: 10, data: "hi"}],
      ...>   header: %EthCore.Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}
      ...> }
      iex> Blockchain.Block.put_block(block, db)
      iex> Blockchain.Block.get_block_hash_by_steps(block |> Blockchain.Block.hash, 0, db)
      {:ok, <<78, 28, 127, 10, 192, 253, 127, 239, 254, 179, 39, 34, 245, 44,
             152, 98, 128, 71, 238, 155, 100, 161, 199, 71, 243, 223, 172, 191,
             74, 99, 128, 63>>}

      # Bad, in the future
      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> block = %Blockchain.Block{
      ...>   transactions: [%Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1::160>>, value: 8, v: 27, r: 9, s: 10, data: "hi"}],
      ...>   header: %EthCore.Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}
      ...> }
      iex> Blockchain.Block.put_block(block, db)
      iex> Blockchain.Block.get_block_hash_by_steps(block |> Blockchain.Block.hash, -1, db)
      :not_found

      # Bad, before the dawn of time
      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> block = %Blockchain.Block{
      ...>   transactions: [%Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1::160>>, value: 8, v: 27, r: 9, s: 10, data: "hi"}],
      ...>   header: %EthCore.Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}
      ...> }
      iex> Blockchain.Block.put_block(block, db)
      iex> Blockchain.Block.get_block_hash_by_steps(block |> Blockchain.Block.hash, 6, db)
      :not_found

      iex> Blockchain.Block.get_block_hash_by_steps(<<1, 2, 3>>, 0, nil)
      {:ok, <<1, 2, 3>>}

      # Legit, back zero and one
      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> block_1 = %Blockchain.Block{
      ...>   transactions: [%Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1::160>>, value: 8, v: 27, r: 9, s: 10, data: "hi"}],
      ...>   header: %EthCore.Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}
      ...> }
      iex> {:ok, block_1_hash} = Blockchain.Block.put_block(block_1, db)
      iex> block_2 = %Blockchain.Block{
      ...>   transactions: [%Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1::160>>, value: 8, v: 27, r: 9, s: 10, data: "hi"}],
      ...>   header: %EthCore.Block.Header{number: 6, parent_hash: block_1_hash, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}
      ...> }
      iex> Blockchain.Block.put_block(block_2, db)
      iex> Blockchain.Block.get_block_hash_by_steps(block_2 |> Blockchain.Block.hash, 0, db)
      {:ok, <<203, 210, 109, 46, 207, 246, 94, 33, 247, 97, 60, 56, 65, 134,
              203, 120, 62, 64, 59, 64, 101, 190, 181, 7, 242, 215, 247, 212,
              107, 12, 92, 9>>}
      iex> Blockchain.Block.get_block_hash_by_steps(block_2 |> Blockchain.Block.hash, 1, db)
      {:ok, <<78, 28, 127, 10, 192, 253, 127, 239, 254, 179, 39, 34, 245, 44,
              152, 98, 128, 71, 238, 155, 100, 161, 199, 71, 243, 223, 172, 191,
              74, 99, 128, 63>>}
  """
  @spec get_block_hash_by_steps(EVM.hash(), non_neg_integer(), DB.db()) ::
          {:ok, EVM.hash()} | :not_found
  def get_block_hash_by_steps(curr_block_hash, steps, db) do
    do_get_block_hash_by_steps(curr_block_hash, steps, db)
  end

  @spec do_get_block_hash_by_steps(EVM.hash(), non_neg_integer(), DB.db()) ::
          {:ok, EVM.hash()} | :not_found
  defp do_get_block_hash_by_steps(block_hash, 0, _db), do: {:ok, block_hash}

  defp do_get_block_hash_by_steps(_block_hash, steps, _db) when steps < 0 or steps > 256,
    do: :not_found

  defp do_get_block_hash_by_steps(block_hash, steps, db) do
    with {:ok, block} <- get_block(block_hash, db) do
      do_get_block_hash_by_steps(block.header.parent_hash, steps - 1, db)
    end
  end

  @doc """
  Returns the parent node for a given block, if it exists.

  We assume a block is a genesis block if it does not have
  a valid `parent_hash` set.

  ## Examples

      iex> Blockchain.Block.get_parent_block(%Blockchain.Block{header: %EthCore.Block.Header{number: 0}}, nil)
      :genesis

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> block = %Blockchain.Block{header: %EthCore.Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}}
      iex> Blockchain.Block.put_block(block, db)
      iex> Blockchain.Block.get_parent_block(%Blockchain.Block{header: %EthCore.Block.Header{parent_hash: block |> Blockchain.Block.hash}}, db)
      {:ok, %Blockchain.Block{header: %EthCore.Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}}}

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> block = %Blockchain.Block{header: %EthCore.Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}}
      iex> Blockchain.Block.get_parent_block(%Blockchain.Block{header: %EthCore.Block.Header{parent_hash: block |> Blockchain.Block.hash}}, db)
      :not_found
  """
  @spec get_parent_block(t, DB.db()) :: {:ok, t} | :genesis | :not_found
  def get_parent_block(block, db) do
    case block.header.number do
      0 -> :genesis
      _ -> get_block(block.header.parent_hash, db)
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
      iex> %Blockchain.Block{}
      ...> |> Blockchain.Block.put_receipt(6, %Blockchain.Transaction.Receipt{state: <<1, 2, 3>>, cumulative_gas: 10, bloom_filter: <<2, 3, 4>>, logs: "hi mom"}, trie.db)
      ...> |> Blockchain.Block.put_receipt(7, %Blockchain.Transaction.Receipt{state: <<4, 5, 6>>, cumulative_gas: 11, bloom_filter: <<5, 6, 7>>, logs: "hi dad"}, trie.db)
      ...> |> Blockchain.Block.get_receipt(6, trie.db)
      %Blockchain.Transaction.Receipt{state: <<1, 2, 3>>, cumulative_gas: 10, bloom_filter: <<2, 3, 4>>, logs: "hi mom"}

      iex> trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      iex> %Blockchain.Block{}
      ...> |> Blockchain.Block.put_receipt(6, %Blockchain.Transaction.Receipt{state: <<1, 2, 3>>, cumulative_gas: 10, bloom_filter: <<2, 3, 4>>, logs: "hi mom"}, trie.db)
      ...> |> Blockchain.Block.get_receipt(7, trie.db)
      nil
  """
  @spec get_receipt(t, integer(), DB.db()) :: Receipt.t() | nil
  def get_receipt(block, i, db) do
    rlp =
      db
      |> Trie.new(block.header.receipts_root)
      |> Trie.get(ExRLP.encode(i))

    case rlp do
      nil ->
        nil

      _ ->
        rlp
        |> ExRLP.decode()
        |> Receipt.deserialize()
    end
  end

  @doc """
  Returns a given transaction from a block. This is
  based on the transactions root where all transactions
  are stored for the given block.

  ## Examples

      iex> trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      iex> %Blockchain.Block{}
      ...> |> Blockchain.Block.put_transaction(6, %Blockchain.Transaction{nonce: 1, v: 1, r: 2, s: 3}, trie.db)
      ...> |> Blockchain.Block.put_transaction(7, %Blockchain.Transaction{nonce: 2, v: 1, r: 2, s: 3}, trie.db)
      ...> |> Blockchain.Block.get_transaction(6, trie.db)
      %Blockchain.Transaction{nonce: 1, v: 1, r: 2, s: 3}

      iex> trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      iex> %Blockchain.Block{}
      ...> |> Blockchain.Block.put_transaction(6, %Blockchain.Transaction{data: "", gas_limit: 100000, gas_price: 3, init: <<96, 3, 96, 5, 1, 96, 0, 82, 96, 0, 96, 32, 243>>, nonce: 5, r: 110274197540583527170567040609004947678532096020311055824363076718114581104395, s: 15165203061950746568488278734700551064641299899120962819352765267479743108366, to: "", v: 27, value: 5}, trie.db)
      ...> |> Blockchain.Block.get_transaction(6, trie.db)
      %Blockchain.Transaction{data: "", gas_limit: 100000, gas_price: 3, init: <<96, 3, 96, 5, 1, 96, 0, 82, 96, 0, 96, 32, 243>>, nonce: 5, r: 110274197540583527170567040609004947678532096020311055824363076718114581104395, s: 15165203061950746568488278734700551064641299899120962819352765267479743108366, to: "", v: 27, value: 5}

      iex> trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      iex> %Blockchain.Block{}
      ...> |> Blockchain.Block.put_transaction(6, %Blockchain.Transaction{nonce: 1, v: 1, r: 2, s: 3}, trie.db)
      ...> |> Blockchain.Block.get_transaction(7, trie.db)
      nil
  """
  @spec get_transaction(t, integer(), DB.db()) :: Transaction.t() | nil
  def get_transaction(block, i, db) do
    serialized_transaction =
      Trie.new(db, block.header.transactions_root)
      |> Trie.get(i |> ExRLP.encode())

    case serialized_transaction do
      nil -> nil
      _ -> Transaction.deserialize(serialized_transaction |> ExRLP.decode())
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
      iex> %Blockchain.Block{transactions: [1,2,3,4,5,6,7]}
      ...> |> Blockchain.Block.put_receipt(6, %Blockchain.Transaction.Receipt{state: <<1, 2, 3>>, cumulative_gas: 10, bloom_filter: <<2, 3, 4>>, logs: "hi mom"}, trie.db)
      ...> |> Blockchain.Block.put_receipt(7, %Blockchain.Transaction.Receipt{state: <<4, 5, 6>>, cumulative_gas: 11, bloom_filter: <<5, 6, 7>>, logs: "hi dad"}, trie.db)
      ...> |> Blockchain.Block.get_cumulative_gas(trie.db)
      11

      iex> trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      iex> %Blockchain.Block{transactions: [1,2,3,4,5,6]}
      ...> |> Blockchain.Block.put_receipt(6, %Blockchain.Transaction.Receipt{state: <<1, 2, 3>>, cumulative_gas: 10, bloom_filter: <<2, 3, 4>>, logs: "hi mom"}, trie.db)
      ...> |> Blockchain.Block.put_receipt(7, %Blockchain.Transaction.Receipt{state: <<4, 5, 6>>, cumulative_gas: 11, bloom_filter: <<5, 6, 7>>, logs: "hi dad"}, trie.db)
      ...> |> Blockchain.Block.get_cumulative_gas(trie.db)
      10

      iex> trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      iex> %Blockchain.Block{}
      ...> |> Blockchain.Block.get_cumulative_gas(trie.db)
      0

      iex> trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      iex> %Blockchain.Block{transactions: [1,2,3,4,5,6,7,8]}
      ...> |> Blockchain.Block.put_receipt(6, %Blockchain.Transaction.Receipt{state: <<1, 2, 3>>, cumulative_gas: 10, bloom_filter: <<2, 3, 4>>, logs: "hi mom"}, trie.db)
      ...> |> Blockchain.Block.put_receipt(7, %Blockchain.Transaction.Receipt{state: <<4, 5, 6>>, cumulative_gas: 11, bloom_filter: <<5, 6, 7>>, logs: "hi dad"}, trie.db)
      ...> |> Blockchain.Block.get_cumulative_gas(trie.db)
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

      iex> %Blockchain.Block{header: %EthCore.Block.Header{state_root: <<1::256>>, number: 100_000, difficulty: 15_500_0000, timestamp: 5_000_000, gas_limit: 500_000}}
      ...> |> Blockchain.Block.new_child(Blockchain.Chain.load_chain(:ropsten), timestamp: 5010000, extra_data: "hi", beneficiary: <<5::160>>)
      %Blockchain.Block{
        header: %EthCore.Block.Header{
          state_root: <<1::256>>,
          beneficiary: <<5::160>>,
          number: 100_001,
          difficulty: 147_507_383,
          timestamp: 5_010_000,
          gas_limit: 500_000,
          extra_data: "hi"
        }
      }

      iex> %Blockchain.Block{header: %EthCore.Block.Header{state_root: <<1::256>>, number: 100_000, difficulty: 1_500_0000, timestamp: 5000, gas_limit: 500_000}}
      ...> |> Blockchain.Block.new_child(Blockchain.Chain.load_chain(:ropsten), state_root: <<2::256>>, timestamp: 6010, extra_data: "hi", beneficiary: <<5::160>>)
      %Blockchain.Block{
        header: %EthCore.Block.Header{
          state_root: <<2::256>>,
          beneficiary: <<5::160>>,
          number: 100_001,
          difficulty: 142_74_924,
          timestamp: 6010,
          gas_limit: 500_000,
          extra_data: "hi"
        }
      }
  """
  @spec new_child(t, Chain.t(), keyword()) :: t
  def new_child(parent_block, chain, opts \\ []) do
    gas_limit = opts[:gas_limit] || parent_block.header.gas_limit
    header = Header.new_child(parent_block.header, opts)

    %__MODULE__{header: header}
    |> set_block_number(parent_block)
    |> set_block_difficulty(chain, parent_block)
    |> set_block_gas_limit(chain, parent_block, gas_limit)
  end

  @doc """
  Calculates the `number` for a new block. This implements Eq.(38) from
  the Yellow Paper.

  ## Examples

      iex> Blockchain.Block.set_block_number(%Blockchain.Block{header: %EthCore.Block.Header{extra_data: "hello"}}, %Blockchain.Block{header: %EthCore.Block.Header{number: 32}})
      %Blockchain.Block{header: %EthCore.Block.Header{number: 33, extra_data: "hello"}}
  """
  @spec set_block_number(t, t) :: t
  def set_block_number(block, parent_block) do
    number = parent_block.header.number + 1
    header = %{block.header | number: number}
    %{block | header: header}
  end

  @doc """
  Set the difficulty of a new block based on Eq.(39), better defined
  in `EthCore.Block.Header`.

  # TODO: Validate these results

  ## Examples

      iex> Blockchain.Block.set_block_difficulty(
      ...>   %Blockchain.Block{header: %EthCore.Block.Header{number: 0, timestamp: 0}},
      ...>   Blockchain.Chain.load_chain(:ropsten),
      ...>   nil
      ...> )
      %Blockchain.Block{header: %EthCore.Block.Header{number: 0, timestamp: 0, difficulty: 1_048_576}}

      iex> Blockchain.Block.set_block_difficulty(
      ...>   %Blockchain.Block{header: %EthCore.Block.Header{number: 1, timestamp: 1_479_642_530}},
      ...>   Blockchain.Chain.load_chain(:ropsten),
      ...>   %Blockchain.Block{header: %EthCore.Block.Header{number: 0, timestamp: 0, difficulty: 1_048_576}}
      ...> )
      %Blockchain.Block{header: %EthCore.Block.Header{number: 1, timestamp: 1_479_642_530, difficulty: 997_888}}
  """
  @spec set_block_difficulty(t, Chain.t(), t) :: t
  def set_block_difficulty(block, chain, parent_block) do
    # TODO: Incorporate more of chain
    difficulty =
      Difficulty.calc(
        block.header,
        if(parent_block, do: parent_block.header, else: nil),
        chain.genesis[:difficulty],
        chain.engine["Ethash"][:minimum_difficulty],
        chain.engine["Ethash"][:difficulty_bound_divisor],
        chain.engine["Ethash"][:homestead_transition]
      )

    %{block | header: %{block.header | difficulty: difficulty}}
  end

  @doc """
  Sets the gas limit of a given block, or raises
  if the block limit is not acceptable. The validity
  check is defined in Eq.(45), Eq.(46) and Eq.(47) of
  the Yellow Paper.

  ## Examples

      iex> Blockchain.Block.set_block_gas_limit(
      ...>   %Blockchain.Block{header: %EthCore.Block.Header{}},
      ...>   Blockchain.Chain.load_chain(:ropsten),
      ...>   %Blockchain.Block{header: %EthCore.Block.Header{gas_limit: 1_000_000}},
      ...>   1_000_500
      ...> )
      %Blockchain.Block{header: %EthCore.Block.Header{gas_limit: 1_000_500}}

      iex> Blockchain.Block.set_block_gas_limit(
      ...>   %Blockchain.Block{header: %EthCore.Block.Header{}},
      ...>   Blockchain.Chain.load_chain(:ropsten),
      ...>   %Blockchain.Block{header: %EthCore.Block.Header{gas_limit: 1_000_000}},
      ...>   2_000_000
      ...> )
      ** (RuntimeError) Block gas limit not valid
  """
  @spec set_block_gas_limit(t, Chain.t(), t, EVM.Gas.t()) :: t
  def set_block_gas_limit(block, chain, parent_block, gas_limit) do
    if not Header.Validation.valid_gas_limit?(
         gas_limit,
         parent_block.header.gas_limit,
         chain.params[:gas_limit_bound_divisor],
         chain.params[:min_gas_limit]
       ),
       do: raise("Block gas limit not valid")

    %{block | header: %{block.header | gas_limit: gas_limit}}
  end

  @doc """
  Attaches an ommer to a block. We do no validation at this stage.

  ## Examples

      iex> Blockchain.Block.add_ommers(%Blockchain.Block{}, [%EthCore.Block.Header{parent_hash: <<1::256>>, ommers_hash: <<2::256>>, beneficiary: <<3::160>>, state_root: <<4::256>>, transactions_root: <<5::256>>, receipts_root: <<6::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<7::256>>, nonce: <<8::64>>}])
      %Blockchain.Block{
        ommers: [
          %EthCore.Block.Header{parent_hash: <<1::256>>, ommers_hash: <<2::256>>, beneficiary: <<3::160>>, state_root: <<4::256>>, transactions_root: <<5::256>>, receipts_root: <<6::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<7::256>>, nonce: <<8::64>>}
        ],
        header: %EthCore.Block.Header{
          ommers_hash: <<59, 196, 156, 242, 196, 38, 21, 97, 112, 6, 73, 111, 12, 88, 35, 155, 72, 175, 82, 0, 163, 128, 115, 236, 45, 99, 88, 62, 88, 80, 122, 96>>
        }
      }
  """
  @spec add_ommers(t, [Header.t()]) :: t
  def add_ommers(block, ommers) do
    total_ommers = block.ommers ++ ommers
    serialized_ommers_list = Enum.map(total_ommers, &Header.serialize/1)
    new_ommers_hash = serialized_ommers_list |> ExRLP.encode() |> Keccak.kec()

    %{block | ommers: total_ommers, header: %{block.header | ommers_hash: new_ommers_hash}}
  end

  @doc """
  Gets an ommer for a given block, based on the ommers_hash.

  ## Examples

      iex> %Blockchain.Block{}
      ...> |> Blockchain.Block.add_ommers([%EthCore.Block.Header{parent_hash: <<1::256>>, ommers_hash: <<2::256>>, beneficiary: <<3::160>>, state_root: <<4::256>>, transactions_root: <<5::256>>, receipts_root: <<6::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<7::256>>, nonce: <<8::64>>}])
      ...> |> Blockchain.Block.get_ommer(0)
      %EthCore.Block.Header{parent_hash: <<1::256>>, ommers_hash: <<2::256>>, beneficiary: <<3::160>>, state_root: <<4::256>>, transactions_root: <<5::256>>, receipts_root: <<6::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<7::256>>, nonce: <<8::64>>}
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

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> chain = Blockchain.Chain.load_chain(:ropsten)
      iex> Blockchain.Genesis.new_block(chain, db)
      ...> |> Blockchain.Block.add_rewards(db)
      ...> |> Blockchain.Block.validate(chain, nil, db)
      :valid

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> chain = Blockchain.Chain.load_chain(:ropsten)
      iex> parent = Blockchain.Genesis.new_block(chain, db)
      ...> child = Blockchain.Block.new_child(parent, chain)
      ...> Blockchain.Block.validate(child, chain, nil, db)
      {:errors, [:non_genesis_block_requires_parent]}

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> chain = Blockchain.Chain.load_chain(:ropsten)
      iex> parent = Blockchain.Genesis.new_block(chain, db)
      iex> beneficiary = <<0x05::160>>
      iex> child = Blockchain.Block.new_child(parent, chain, beneficiary: beneficiary)
      ...>         |> Blockchain.Block.add_rewards(db, chain.engine["Ethash"][:block_reward])
      iex> Blockchain.Block.validate(child, chain, parent, db)
      :valid
  """
  @spec validate(t, Chain.t(), t, DB.db()) :: :valid | {:invalid, [atom()]}
  def validate(block, chain, parent_block, db) do
    if block.header.number > 0 and parent_block == nil do
      {:errors, [:non_genesis_block_requires_parent]}
    else
      with :valid <-
             Header.validate(
               block.header,
               if(parent_block, do: parent_block.header, else: nil),
               chain.engine["Ethash"][:homestead_transition],
               chain.genesis[:difficulty],
               chain.engine["Ethash"][:minimum_difficulty],
               chain.engine["Ethash"][:difficulty_bound_divisor],
               chain.params[:gas_limit_bound_divisor],
               chain.params[:min_gas_limit]
             ) do
        # Pass to holistic validity check
        HolisticValidity.validate(block, chain, parent_block, db)
      end
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

  # TODO: Add a rich set of test cases in `block_test.exs`

  ## Examples

      # Create a contract
  """
  @spec add_transactions(t, [Transaction.t()], DB.db()) :: t
  def add_transactions(block, transactions, db) do
    trx_count = get_transaction_count(block)

    do_add_transactions(block, transactions, db, trx_count)
  end

  @spec do_add_transactions(t, [Transaction.t()], DB.db(), integer()) :: t
  defp do_add_transactions(block, [], _, _), do: block

  defp do_add_transactions(
         block = %__MODULE__{header: header},
         [trx | transactions],
         db,
         trx_count
       ) do
    state = Trie.new(db, header.state_root)
    # TODO: How do we deal with invalid transactions
    {new_state, gas_used, logs} = Transaction.execute(state, trx, header)

    total_gas_used = block.header.gas_used + gas_used

    # TODO: Add bloom filter
    receipt = %Receipt{
      state: new_state.root_hash,
      cumulative_gas: total_gas_used,
      logs: logs
    }

    updated_block =
      block
      |> put_state(new_state)
      |> put_gas_used(total_gas_used)
      |> put_receipt(trx_count, receipt, db)
      |> put_transaction(trx_count, trx, db)

    do_add_transactions(updated_block, transactions, db, trx_count + 1)
  end

  # Updates a block to have a new state root given a state object
  @spec put_state(t, EVM.state()) :: t
  def put_state(block, new_state) do
    header = %{block.header | state_root: new_state.root_hash}
    %{block | header: header}
  end

  # Updates a block to have total gas used set in the header
  @spec put_gas_used(t, EVM.Gas.t()) :: t
  def put_gas_used(block, gas_used) do
    header = %{block.header | gas_used: gas_used}
    %{block | header: header}
  end

  @doc """
  Updates a block by adding a receipt to the list of receipts
  at position `i`.

  ## Examples

      iex> trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      iex> block = Blockchain.Block.put_receipt(%Blockchain.Block{}, 5, %Blockchain.Transaction.Receipt{state: <<1, 2, 3>>, cumulative_gas: 10, bloom_filter: <<2, 3, 4>>, logs: "hi mom"}, trie.db)
      iex> MerklePatriciaTree.Trie.into(block.header.receipts_root, trie)
      ...> |> MerklePatriciaTree.Trie.Inspector.all_values()
      [{<<5>>, <<208, 131, 1, 2, 3, 10, 131, 2, 3, 4, 134, 104, 105, 32, 109, 111, 109>>}]
  """
  @spec put_receipt(t, integer(), Receipt.t(), DB.db()) :: t
  def put_receipt(block, i, receipt, db) do
    receipt_rlp =
      receipt
      |> Receipt.serialize()
      |> ExRLP.encode()

    receipts_root =
      db
      |> Trie.new(block.header.receipts_root)
      |> Trie.update(ExRLP.encode(i), receipt_rlp)

    header = %{block.header | receipts_root: receipts_root.root_hash}
    %{block | header: header}
  end

  @doc """
  Updates a block by adding a transaction to the list of transactions
  and updating the transactions_root in the header at position `i`, which
  should be equivalent to the current number of transactions.

  ## Examples

      iex> trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      iex> block = Blockchain.Block.put_transaction(%Blockchain.Block{}, 0, %Blockchain.Transaction{nonce: 1, v: 2, r: 3, s: 4}, trie.db)
      iex> block.transactions
      [%Blockchain.Transaction{nonce: 1, v: 2, r: 3, s: 4}]
      iex> MerklePatriciaTree.Trie.into(block.header.transactions_root, trie)
      ...> |> MerklePatriciaTree.Trie.Inspector.all_values()
      [{<<0x80>>, <<201, 1, 128, 128, 128, 128, 128, 2, 3, 4>>}]
  """
  @spec put_transaction(t(), integer(), Transaction.t(), DB.db()) :: t()
  def put_transaction(block, i, tx, db) do
    total_transactions = block.transactions ++ [tx]
    tx_rlp = tx |> Transaction.serialize() |> ExRLP.encode()

    transactions_root =
      db
      |> Trie.new(block.header.transactions_root)
      |> Trie.update(ExRLP.encode(i), tx_rlp)

    header = %{block.header | transactions_root: transactions_root.root_hash}
    %{block | transactions: total_transactions, header: header}
  end

  @doc """
  Adds the rewards to miners (including for ommers) to a block.
  This is defined in Section 11.3, Eq.(159-163) of the Yellow Paper.
  """
  @spec add_rewards(t, DB.db(), EVM.Wei.t()) :: t
  def add_rewards(block, db, reward_wei \\ @reward_wei) do
    # TODO: Add ommer rewards

    cond do
      genesis?(block) ->
        block

      is_nil(block.header.beneficiary) ->
        raise("Unable to add block rewards, beneficiary is nil")

      true ->
        do_add_rewards(block, db, reward_wei)
    end
  end

  @spec do_add_rewards(t, DB.db(), EVM.Wei.t()) :: t
  defp do_add_rewards(block, db, reward_wei) do
    state = get_state(block, db)
    new_state = Account.add_wei(state, block.header.beneficiary, reward_wei)
    set_state(block, new_state)
  end

  @doc """
  Sets a given block header field as a shortcut when
  we want to change a single field.

  ## Examples

      iex> %Blockchain.Block{}
      ...> |> Blockchain.Block.put_header(:number, 5)
      %Blockchain.Block{
        header: %EthCore.Block.Header{
          number: 5
        }
      }
  """
  @spec put_header(t, any(), any()) :: t
  def put_header(block, key, value) do
    new_header = Map.put(block.header, key, value)
    %{block | header: new_header}
  end

  @doc """
  Returns a trie rooted at the state_root of a given block.

  ## Examples

      iex> db = MerklePatriciaTree.Test.random_ets_db(:get_state)
      iex> Blockchain.Block.get_state(%Blockchain.Block{header: %EthCore.Block.Header{state_root: <<5::256>>}}, db)
      %MerklePatriciaTree.Trie{root_hash: <<5::256>>, db: {MerklePatriciaTree.DB.ETS, :get_state}}
  """
  @spec get_state(t, DB.db()) :: Trie.t()
  def get_state(block, db) do
    Trie.new(db, block.header.state_root)
  end

  @doc """
  Sets the state_root of a given block from a trie.

  ## Examples

      iex> trie = %MerklePatriciaTree.Trie{root_hash: <<5::256>>, db: {MerklePatriciaTree.DB.ETS, :get_state}}
      iex> Blockchain.Block.set_state(%Blockchain.Block{}, trie)
      %Blockchain.Block{header: %EthCore.Block.Header{state_root: <<5::256>>}}
  """
  @spec set_state(t, Trie.t()) :: t
  def set_state(block, trie) do
    put_header(block, :state_root, trie.root_hash)
  end

  @doc """
  Returns whether or not a block is a genesis block, based on block number.
  """
  @spec genesis?(t()) :: boolean()
  def genesis?(block), do: block.header.number == 0
end
