defmodule Blockchain.Block do
  @moduledoc """
  This module effective encodes a Block, the heart of the blockchain. A chain is
  formed when blocks point to previous blocks, either as a parent or an ommer (uncle).
  For more information, see Section 4.4 of the Yellow Paper.
  """

  alias Block.Header
  alias Blockchain.Transaction
  alias Blockchain.Transaction.Receipt
  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.DB

  # Defined in Eq.(18)
  defstruct [
    block_hash: nil,   # Hash for this block, acts simply as a cache.
    header: %Header{}, # B_H
    transactions: [],  # B_T
    ommers: [],        # B_U
  ]

  @type t :: %__MODULE__{
    block_hash: EVM.hash | nil,
    header: Header.t,
    transactions: [Transaction.t],
    ommers: [Header.t],
  }

  @doc """
  Encodes a block such that it can be represented in
  RLP encoding. This is defined as `L_B` Eq.(33) in the Yellow Paper.

  ## Examples

    iex> Blockchain.Block.serialize(%Blockchain.Block{
    ...>   header: %Block.Header{parent_hash: <<1::256>>, ommers_hash: <<2::256>>, beneficiary: <<3::160>>, state_root: <<4::256>>, transactions_root: <<5::256>>, receipts_root: <<6::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<7::256>>, nonce: <<8::64>>},
    ...>   transactions: [%Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1::160>>, value: 8, v: 27, r: 9, s: 10, data: "hi"}],
    ...>   ommers: [%Block.Header{parent_hash: <<11::256>>, ommers_hash: <<12::256>>, beneficiary: <<13::160>>, state_root: <<14::256>>, transactions_root: <<15::256>>, receipts_root: <<16::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<17::256>>, nonce: <<18::64>>}]
    ...> })
    [
      [<<1::256>>, <<2::256>>, <<3::160>>, <<4::256>>, <<5::256>>, <<6::256>>, <<>>, 5, 1, 5, 3, 6, "Hi mom", <<7::256>>, <<8::64>>],
      [[5, 6, 7, <<1::160>>, 8, "hi", 27, 9, 10]],
      [[<<11::256>>, <<12::256>>, <<13::160>>, <<14::256>>, <<15::256>>, <<16::256>>, <<>>, 5, 1, 5, 3, 6, "Hi mom", <<17::256>>, <<18::64>>]]
    ]

    iex> Blockchain.Block.serialize(%Blockchain.Block{})
    [["", <<128>>, "", <<128>>, <<128>>, <<128>>, "", nil, nil, 0, 0, nil, "", nil, nil], [], []]
  """
  @spec serialize(t) :: ExRLP.t
  def serialize(block) do
    [
      Header.serialize(block.header),
      Enum.map(block.transactions, &Transaction.serialize/1),
      Enum.map(block.ommers, &Header.serialize/1),
    ]
  end

  @doc """
  Decodes a block from an RLP encoding. Effectively inverts
  L_B defined in Eq.(33).

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
  @spec deserialize(ExRLP.t) :: t
  def deserialize(rlp) do
    [
      header,
      transactions,
      ommers
    ] = rlp

    %__MODULE__{
      header: Header.deserialize(header),
      transactions: Enum.map(transactions, &Transaction.deserialize/1),
      ommers: Enum.map(ommers, &Header.deserialize/1),
    }
  end

  @doc """
  Computes hash of a block

  TODO: Make better, a lot better

  ## Examples

      iex> %Blockchain.Block{header: %Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}}
      ...> |> Blockchain.Block.hash()
      <<202, 152, 99, 191, 141, 40, 215, 68, 194, 178, 174, 74, 204, 72, 225, 237, 129, 158, 212, 244, 39, 240, 51, 137, 141, 68, 220, 206, 23, 64, 113, 149>>
  """
  @spec hash(t) :: EVM.hash
  def hash(block) do
    block.header |> Header.serialize() |> ExRLP.encode |> :keccakf1600.sha3_256 # sha3
  end

  @doc """
  Stores a given block in the database.

  ## Examples

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> block = %Blockchain.Block{header: %Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}}
      iex> Blockchain.Block.put_block(block, db)
      {:ok, <<202, 152, 99, 191, 141, 40, 215, 68, 194, 178, 174, 74, 204, 72, 225, 237, 129, 158, 212, 244, 39, 240, 51, 137, 141, 68, 220, 206, 23, 64, 113, 149>>}
      iex> MerklePatriciaTree.DB.get(db, block |> Blockchain.Block.hash)
      {:ok, <<220, 217, 131, 1, 2, 3, 129, 128, 131, 2, 3, 4, 129, 128, 129, 128, 129, 128, 128, 100, 5, 128, 128, 11, 128, 1, 2, 192, 192>>}
  """
  @spec put_block(t, DB.db) :: {:ok, EVM.hash}
  def put_block(block, db) do
    hash = block |> hash

    :ok = MerklePatriciaTree.DB.put!(db, hash, block |> serialize |> ExRLP.encode)

    {:ok, hash}
  end

  @doc """
  Returns a given block from the database, if
  the node exists in the database.

  ## Examples

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> Blockchain.Block.get_block(<<1, 2, 3>>, db)
      :not_found

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> block = %Blockchain.Block{
      ...>   transactions: [%Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1::160>>, value: 8, v: 27, r: 9, s: 10, data: "hi"}],
      ...>   header: %Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}
      ...> }
      iex> Blockchain.Block.put_block(block, db)
      iex> Blockchain.Block.get_block(block |> Blockchain.Block.hash, db)
      {:ok, %Blockchain.Block{
        transactions: [%Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1::160>>, value: 8, v: 27, r: 9, s: 10, data: "hi"}],
        header: %Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}
      }}
  """
  @spec get_block(EVM.hash, DB.db) :: {:ok, t} | :not_found
  def get_block(block_hash, db) do
    with {:ok, rlp} <- MerklePatriciaTree.DB.get(db, block_hash) do
      {:ok, rlp |> ExRLP.decode |> deserialize()}
    end
  end

  @doc """
  Returns the parent node for a given block,
  if it exists.

  We assume a block is a genesis block if it does not have
  a valid `parent_hash` set.

  ## Examples

      iex> Blockchain.Block.get_parent_block(%Blockchain.Block{header: %Block.Header{number: 0}}, nil)
      :genesis

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> block = %Blockchain.Block{header: %Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}}
      iex> Blockchain.Block.put_block(block, db)
      iex> Blockchain.Block.get_parent_block(%Blockchain.Block{header: %Block.Header{parent_hash: block |> Blockchain.Block.hash}}, db)
      {:ok, %Blockchain.Block{header: %Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}}}

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> block = %Blockchain.Block{header: %Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}}
      iex> Blockchain.Block.get_parent_block(%Blockchain.Block{header: %Block.Header{parent_hash: block |> Blockchain.Block.hash}}, db)
      :not_found
  """
  @spec get_parent_block(t, DB.db) :: {:ok, t} | :genesis | :not_found
  def get_parent_block(block, db) do
    case block.header.number do
      0 -> :genesis
      block_hash -> get_block(block.header.parent_hash, db)
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

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> %Blockchain.Block{}
      ...> |> Blockchain.Block.put_receipt(6, %Blockchain.Transaction.Receipt{state: <<1, 2, 3>>, cumulative_gas: 10, bloom_filter: <<2, 3, 4>>, logs: "hi mom"}, db)
      ...> |> Blockchain.Block.put_receipt(7, %Blockchain.Transaction.Receipt{state: <<4, 5, 6>>, cumulative_gas: 11, bloom_filter: <<5, 6, 7>>, logs: "hi dad"}, db)
      ...> |> Blockchain.Block.get_receipt(6, db)
      %Blockchain.Transaction.Receipt{state: <<1, 2, 3>>, cumulative_gas: 10, bloom_filter: <<2, 3, 4>>, logs: "hi mom"}

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> %Blockchain.Block{}
      ...> |> Blockchain.Block.put_receipt(6, %Blockchain.Transaction.Receipt{state: <<1, 2, 3>>, cumulative_gas: 10, bloom_filter: <<2, 3, 4>>, logs: "hi mom"}, db)
      ...> |> Blockchain.Block.get_receipt(7, db)
      nil
  """
  @spec get_receipt(t, integer(), DB.db) :: Receipt.t | nil
  def get_receipt(block, i, db) do
    serialized_receipt =
      Trie.new(db, block.header.receipts_root)
      |> Trie.get(i |> ExRLP.encode)

    case serialized_receipt do
      nil -> nil
      _ -> Receipt.deserialize(serialized_receipt |> ExRLP.decode)
    end
  end

  @doc """
  Returns a given transaction from a block. This is
  based on the transactions root where all transactions
  are stored for the given block.

  ## Examples

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> %Blockchain.Block{}
      ...> |> Blockchain.Block.put_transaction(6, %Blockchain.Transaction{nonce: 1, v: 1, r: 2, s: 3}, db)
      ...> |> Blockchain.Block.put_transaction(7, %Blockchain.Transaction{nonce: 2, v: 1, r: 2, s: 3}, db)
      ...> |> Blockchain.Block.get_transaction(6, db)
      %Blockchain.Transaction{nonce: 1, v: 1, r: 2, s: 3}

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> %Blockchain.Block{}
      ...> |> Blockchain.Block.put_transaction(6, %Blockchain.Transaction{data: "", gas_limit: 100000, gas_price: 3, init: <<96, 3, 96, 5, 1, 96, 0, 82, 96, 0, 96, 32, 243>>, nonce: 5, r: 110274197540583527170567040609004947678532096020311055824363076718114581104395, s: 15165203061950746568488278734700551064641299899120962819352765267479743108366, to: "", v: 27, value: 5}, db)
      ...> |> Blockchain.Block.get_transaction(6, db)
      %Blockchain.Transaction{data: "", gas_limit: 100000, gas_price: 3, init: <<96, 3, 96, 5, 1, 96, 0, 82, 96, 0, 96, 32, 243>>, nonce: 5, r: 110274197540583527170567040609004947678532096020311055824363076718114581104395, s: 15165203061950746568488278734700551064641299899120962819352765267479743108366, to: "", v: 27, value: 5}

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> %Blockchain.Block{}
      ...> |> Blockchain.Block.put_transaction(6, %Blockchain.Transaction{nonce: 1, v: 1, r: 2, s: 3}, db)
      ...> |> Blockchain.Block.get_transaction(7, db)
      nil
  """
  @spec get_transaction(t, integer(), DB.db) :: Transaction.t | nil
  def get_transaction(block, i, db) do
    serialized_transaction =
      Trie.new(db, block.header.transactions_root)
      |> Trie.get(i |> ExRLP.encode)

    case serialized_transaction do
      nil -> nil
      _ -> Transaction.deserialize(serialized_transaction |> ExRLP.decode)
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

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> %Blockchain.Block{transactions: [1,2,3,4,5,6,7]}
      ...> |> Blockchain.Block.put_receipt(6, %Blockchain.Transaction.Receipt{state: <<1, 2, 3>>, cumulative_gas: 10, bloom_filter: <<2, 3, 4>>, logs: "hi mom"}, db)
      ...> |> Blockchain.Block.put_receipt(7, %Blockchain.Transaction.Receipt{state: <<4, 5, 6>>, cumulative_gas: 11, bloom_filter: <<5, 6, 7>>, logs: "hi dad"}, db)
      ...> |> Blockchain.Block.get_cumulative_gas(db)
      11

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> %Blockchain.Block{transactions: [1,2,3,4,5,6]}
      ...> |> Blockchain.Block.put_receipt(6, %Blockchain.Transaction.Receipt{state: <<1, 2, 3>>, cumulative_gas: 10, bloom_filter: <<2, 3, 4>>, logs: "hi mom"}, db)
      ...> |> Blockchain.Block.put_receipt(7, %Blockchain.Transaction.Receipt{state: <<4, 5, 6>>, cumulative_gas: 11, bloom_filter: <<5, 6, 7>>, logs: "hi dad"}, db)
      ...> |> Blockchain.Block.get_cumulative_gas(db)
      10

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> %Blockchain.Block{}
      ...> |> Blockchain.Block.get_cumulative_gas(db)
      0

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> %Blockchain.Block{transactions: [1,2,3,4,5,6,7,8]}
      ...> |> Blockchain.Block.put_receipt(6, %Blockchain.Transaction.Receipt{state: <<1, 2, 3>>, cumulative_gas: 10, bloom_filter: <<2, 3, 4>>, logs: "hi mom"}, db)
      ...> |> Blockchain.Block.put_receipt(7, %Blockchain.Transaction.Receipt{state: <<4, 5, 6>>, cumulative_gas: 11, bloom_filter: <<5, 6, 7>>, logs: "hi dad"}, db)
      ...> |> Blockchain.Block.get_cumulative_gas(db)
      ** (RuntimeError) cannot find receipt
  """
  @spec get_cumulative_gas(t, atom()) :: EVM.Gas.t
  def get_cumulative_gas(block=%__MODULE__{}, db) do
    case get_transaction_count(block) do
      0 -> 0
      i -> case get_receipt(block, i, db) do
        nil -> raise "cannot find receipt"
        receipt -> receipt.cumulative_gas
      end
    end
  end

  # TODO: gen_genesis_block

  @doc """
  Creates a new block from a parent block. This will handle setting
  the block number, the difficulty and will keep the `gas_limit` the
  same as the parent's block unless specified in `opts`.

  A timestamp is required for difficulty calculation.
  If it's not specified, it will default to the current system time.

  This function is not directly addressed in the Yellow Paper.

  ## Examples

      iex> %Blockchain.Block{header: %Block.Header{state_root: <<1::256>>, number: 100_000, difficulty: 131072, timestamp: 5000, gas_limit: 500_000}}
      ...> |> Blockchain.Block.gen_child_block(timestamp: 5010, extra_data: "hi", beneficiary: <<5::160>>)
      %Blockchain.Block{header: %Block.Header{state_root: <<1::256>>, beneficiary: <<5::160>>, number: 100_001, difficulty: 131136, timestamp: 5010, gas_limit: 500_000, extra_data: "hi"}}

      iex> %Blockchain.Block{header: %Block.Header{state_root: <<1::256>>, number: 100_000, difficulty: 131072, timestamp: 5000, gas_limit: 500_000}}
      ...> |> Blockchain.Block.gen_child_block(state_root: <<2::256>>, timestamp: 5010, extra_data: "hi", beneficiary: <<5::160>>)
      %Blockchain.Block{header: %Block.Header{state_root: <<2::256>>, beneficiary: <<5::160>>, number: 100_001, difficulty: 131136, timestamp: 5010, gas_limit: 500_000, extra_data: "hi"}}
  """
  @spec gen_child_block(t, [timestamp: EVM.timestamp, gas_limit: EVM.val, beneficiary: EVM.address, extra_data: binary(), state_root: EVM.hash]) :: t
  def gen_child_block(parent_block, opts \\ []) do
    timestamp = opts[:timestamp] || System.system_time(:second)
    gas_limit = opts[:gas_limit] || parent_block.header.gas_limit
    beneficiary = opts[:beneficiary] || <<>>
    extra_data = opts[:extra_data] || <<>>
    state_root = opts[:state_root] || parent_block.header.state_root

    %Blockchain.Block{header: %Block.Header{state_root: state_root, timestamp: timestamp, extra_data: extra_data, beneficiary: beneficiary}}
    |> identity()
    |> set_block_number(parent_block)
    |> set_block_difficulty(parent_block)
    |> set_block_gas_limit(parent_block, gas_limit)
  end

  @spec identity(t) :: t
  def identity(block), do: block

  @doc """
  Calculates the `number` for a new block. This implements Eq.(38) from
  the Yellow Paper.

  ## Examples

      iex> Blockchain.Block.set_block_number(%Blockchain.Block{header: %Block.Header{extra_data: "hello"}}, %Blockchain.Block{header: %Block.Header{number: 32}})
      %Blockchain.Block{header: %Block.Header{number: 33, extra_data: "hello"}}
  """
  @spec set_block_number(t, t) :: t
  def set_block_number(block=%Blockchain.Block{header: header}, _parent_block=%Blockchain.Block{header: %Block.Header{number: parent_number}}) do
    %{block | header: %{header | number: parent_number + 1}}
  end

  @doc """
  Set the difficulty of a new block based on Eq.(39), better defined
  in Block.Header`.

  # TODO: Validate these results

  ## Examples

      iex> Blockchain.Block.set_block_difficulty(
      ...>   %Blockchain.Block{header: %Block.Header{number: 0, timestamp: 55}},
      ...>   nil
      ...> )
      %Blockchain.Block{header: %Block.Header{number: 0, timestamp: 55, difficulty: 131_072}}

      iex> Blockchain.Block.set_block_difficulty(
      ...>   %Blockchain.Block{header: %Block.Header{number: 33, timestamp: 66}},
      ...>   %Blockchain.Block{header: %Block.Header{number: 32, timestamp: 55, difficulty: 300_000}}
      ...> )
      %Blockchain.Block{header: %Block.Header{number: 33, timestamp: 66, difficulty: 300_146}}
  """
  @spec set_block_difficulty(t, t) :: t
  def set_block_difficulty(block=%Blockchain.Block{header: header}, parent_block) do
    difficulty = Header.get_difficulty(header, (if parent_block, do: parent_block.header, else: nil))

    %{block | header: %{header | difficulty: difficulty}}
  end

  @doc """
  Sets the gas limit of a given block, or raises
  if the block limit is not acceptable. The validity
  check is defined in Eq.(45), Eq.(46) and Eq.(47) of
  the Yellow Paper.

  ## Examples

      iex> Blockchain.Block.set_block_gas_limit(
      ...>   %Blockchain.Block{header: %Block.Header{}},
      ...>   %Blockchain.Block{header: %Block.Header{gas_limit: 1_000_000}},
      ...>   1_000_500
      ...> )
      %Blockchain.Block{header: %Block.Header{gas_limit: 1_000_500}}

      iex> Blockchain.Block.set_block_gas_limit(
      ...>   %Blockchain.Block{header: %Block.Header{}},
      ...>   %Blockchain.Block{header: %Block.Header{gas_limit: 1_000_000}},
      ...>   2_000_000
      ...> )
      ** (RuntimeError) Block gas limit not valid
  """
  @spec set_block_gas_limit(t, t, EVM.Gas.t) :: t
  def set_block_gas_limit(block, parent_block, gas_limit) do
    if not Header.is_gas_limit_valid?(gas_limit, parent_block.header.gas_limit), do: raise "Block gas limit not valid"

    %{block | header: %{block.header | gas_limit: gas_limit}}
  end

  @doc """
  Attaches an ommer to a block. We do no validation at this stage.

  ## Examples

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> Blockchain.Block.add_ommers_to_block(%Blockchain.Block{}, [%Block.Header{parent_hash: <<1::256>>, ommers_hash: <<2::256>>, beneficiary: <<3::160>>, state_root: <<4::256>>, transactions_root: <<5::256>>, receipts_root: <<6::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<7::256>>, nonce: <<8::64>>}], db)
      %Blockchain.Block{ommers: [%Block.Header{parent_hash: <<1::256>>, ommers_hash: <<2::256>>, beneficiary: <<3::160>>, state_root: <<4::256>>, transactions_root: <<5::256>>, receipts_root: <<6::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<7::256>>, nonce: <<8::64>>}], header: %Block.Header{ommers_hash: <<29, 110, 115, 211, 86, 204, 153, 210, 198, 241, 37, 134, 165, 127, 24, 206, 16, 76, 90, 176, 36, 67, 23, 207, 191, 214, 58, 43, 222, 218, 8, 225>>}}
  """
  @spec add_ommers_to_block(t, [Header.t], DB.db) :: t
  def add_ommers_to_block(block, ommers, db) do
    do_add_ommers_to_block(block, ommers, db, Enum.count(block.ommers))
  end

  defp do_add_ommers_to_block(block, [], _, _), do: block
  defp do_add_ommers_to_block(block, [ommer|ommers], db, i) do
    updated_ommers_hash =
      Trie.new(db, block.header.ommers_hash)
      |> Trie.update(ExRLP.encode(i), Header.serialize(ommer) |> ExRLP.encode)

    updated_block = %{block | ommers: block.ommers ++ [ommer], header: %{block.header | ommers_hash: updated_ommers_hash.root_hash}}

    do_add_ommers_to_block(updated_block, ommers, db, i + 1)
  end

  @doc """
  Gets an ommer for a given block, based on the ommers_hash.

  ## Examples

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> %Blockchain.Block{}
      ...> |> Blockchain.Block.add_ommers_to_block([%Block.Header{parent_hash: <<1::256>>, ommers_hash: <<2::256>>, beneficiary: <<3::160>>, state_root: <<4::256>>, transactions_root: <<5::256>>, receipts_root: <<6::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<7::256>>, nonce: <<8::64>>}], db)
      ...> |> Blockchain.Block.get_ommer(0, db)
      %Block.Header{parent_hash: <<1::256>>, ommers_hash: <<2::256>>, beneficiary: <<3::160>>, state_root: <<4::256>>, transactions_root: <<5::256>>, receipts_root: <<6::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<7::256>>, nonce: <<8::64>>}
  """
  @spec get_ommer(t, integer(), DB.db) :: Header.t
  def get_ommer(block, i, db) do
    serialized_ommer =
      Trie.new(db, block.header.ommers_hash)
      |> Trie.get(ExRLP.encode(i))

    case serialized_ommer do
      nil -> nil
      _ -> Header.deserialize(serialized_ommer |> ExRLP.decode)
    end
  end

  @doc """
  Determines whether or not a block is valid. This is
  defined in Eq.(29) of the Yellow Paper.

  Note, this is a serious intensive operation, and not
  faint of heart (since we need to run all transaction
  in the block to validate the block).

  ## Examples

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> beneficiary = <<0x05::160>>
      iex> private_key = <<1::256>>
      iex> sender = <<125, 110, 153, 187, 138, 191, 140, 192, 19, 187, 14, 145, 45, 11, 23, 101, 150, 254, 123, 136>> # based on simple private key
      iex> machine_code = EVM.MachineCode.compile([:push1, 3, :push1, 5, :add, :push1, 0x00, :mstore, :push1, 0, :push1, 32, :return])
      iex> trx = %Blockchain.Transaction{nonce: 5, gas_price: 3, gas_limit: 100_000, to: <<>>, value: 5, init: machine_code}
      ...>       |> Blockchain.Transaction.Signature.sign_transaction(private_key)
      iex> state = MerklePatriciaTree.Trie.new(db)
      ...>         |> Blockchain.Account.put_account(sender, %Blockchain.Account{balance: 400_000, nonce: 5})
      iex> parent_block = %Blockchain.Block{header: %Block.Header{number: 50, state_root: state.root_hash, difficulty: 50_000, timestamp: 9999, gas_limit: 125_001}}
      iex> block = Blockchain.Block.gen_child_block(parent_block, beneficiary: beneficiary, timestamp: 10000, gas_limit: 125_001)
      ...>         |> Blockchain.Block.add_transactions_to_block([trx], db)
      iex> Blockchain.Block.is_holistic_valid?(block, parent_block, db)
      :valid

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> beneficiary = <<0x05::160>>
      iex> private_key = <<1::256>>
      iex> sender = <<125, 110, 153, 187, 138, 191, 140, 192, 19, 187, 14, 145, 45, 11, 23, 101, 150, 254, 123, 136>> # based on simple private key
      iex> machine_code = EVM.MachineCode.compile([:push1, 3, :push1, 5, :add, :push1, 0x00, :mstore, :push1, 0, :push1, 32, :return])
      iex> trx = %Blockchain.Transaction{nonce: 5, gas_price: 3, gas_limit: 100_000, to: <<>>, value: 5, init: machine_code}
      ...>       |> Blockchain.Transaction.Signature.sign_transaction(private_key)
      iex> state = MerklePatriciaTree.Trie.new(db)
      ...>         |> Blockchain.Account.put_account(sender, %Blockchain.Account{balance: 400_000, nonce: 5})
      iex> parent_block = %Blockchain.Block{header: %Block.Header{number: 50, state_root: state.root_hash, difficulty: 50_000, timestamp: 9999, gas_limit: 125_001}}
      iex> block = Blockchain.Block.gen_child_block(parent_block, beneficiary: beneficiary, timestamp: 10000, gas_limit: 125_001)
      ...>         |> Blockchain.Block.add_transactions_to_block([trx], db)
      iex> %{block | header: %{block.header | state_root: <<1,2,3>>, ommers_hash: <<2,3,4>>, transactions_root: <<3,4,5>>, receipts_root: <<4,5,6>>}}
      ...> |> Blockchain.Block.is_holistic_valid?(parent_block, db)
      {:invalid, [:state_root_mismatch, :ommers_hash_mismatch, :transactions_root_mismatch, :receipts_root_mismatch]}
  """
  @spec is_holistic_valid?(t, t, DB.db) :: :valid | {:invalid, [atom()]}
  def is_holistic_valid?(block, parent_block, db) do
    child_block =
      gen_child_block(parent_block, beneficiary: block.header.beneficiary, timestamp: block.header.timestamp, gas_limit: block.header.gas_limit, extra_data: block.header.extra_data)
      |> add_transactions_to_block(block.transactions, db)
      |> add_ommers_to_block(block.ommers, db)

    # The following checks Holistic Validity, as defined in Eq.(29)
    errors = []
      ++ if child_block.header.state_root == block.header.state_root, do: [], else: [:state_root_mismatch]
      ++ if child_block.header.ommers_hash == block.header.ommers_hash, do: [], else: [:ommers_hash_mismatch]
      ++ if child_block.header.transactions_root == block.header.transactions_root, do: [], else: [:transactions_root_mismatch]
      ++ if child_block.header.receipts_root == block.header.receipts_root, do: [], else: [:receipts_root_mismatch]

    if errors == [], do: :valid, else: {:invalid, errors}
  end

  @doc """
  Checks the validity of a block, including the validity of the
  header and the transactions. This should verify that we should
  accept the authenticity of a block.

  # TODO: Add examples
  """
  @spec is_fully_valid?(t, t, DB.db) :: :valid | {:invalid, [atom()]}
  def is_fully_valid?(block, parent_block, db) do
    if block.header.number == 0 and parent_block == nil do
      # We're going to assume genesis blocks are valid.
      # We just need to verify no one can falsely advertise one.
      :valid
    else
      if parent_block == nil do
        {:errors, [:non_genesis_block_requires_parent]}
      else
        with :valid <- Block.Header.is_valid?(block.header, parent_block.header) do
          # Pass to holistic validity check
          is_holistic_valid?(block, parent_block, db)
        end
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
  in `:ets` or `:leveldb`. See `MerklePatriciaTree.DB`.

  # TODO: Add a rich set of test cases in `block_test.exs`

  ## Examples

      # Create a contract
      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> beneficiary = <<0x05::160>>
      iex> private_key = <<1::256>>
      iex> sender = <<125, 110, 153, 187, 138, 191, 140, 192, 19, 187, 14, 145, 45, 11, 23, 101, 150, 254, 123, 136>> # based on simple private key
      iex> contract_address = Blockchain.Contract.new_contract_address(sender, 6)
      iex> machine_code = EVM.MachineCode.compile([:push1, 3, :push1, 5, :add, :push1, 0x00, :mstore, :push1, 0, :push1, 32, :return])
      iex> trx = %Blockchain.Transaction{nonce: 5, gas_price: 3, gas_limit: 100_000, to: <<>>, value: 5, init: machine_code}
      ...>           |> Blockchain.Transaction.Signature.sign_transaction(private_key)
      iex> state = MerklePatriciaTree.Trie.new(db)
      ...>           |> Blockchain.Account.put_account(sender, %Blockchain.Account{balance: 400_000, nonce: 5})
      iex> block = %Blockchain.Block{header: %Block.Header{state_root: state.root_hash, beneficiary: beneficiary}, transactions: []}
      ...>           |> Blockchain.Block.add_transactions_to_block([trx], db)
      iex> Enum.count(block.transactions)
      1
      iex> Blockchain.Block.get_receipt(block, 0, db)
      %Blockchain.Transaction.Receipt{bloom_filter: "", cumulative_gas: 53756, logs: "", state: block.header.state_root}
      iex> Blockchain.Block.get_transaction(block, 0, db)
      %Blockchain.Transaction{data: "", gas_limit: 100000, gas_price: 3, init: <<96, 3, 96, 5, 1, 96, 0, 82, 96, 0, 96, 32, 243>>, nonce: 5, r: 14159411915843247798541244544791455673077363609967175479682740936374424047718, s: 54974362865507454783589777536677081181084754879294507743788973783077639473486, to: "", v: 28, value: 5}
      iex> MerklePatriciaTree.Trie.new(db, block.header.state_root)
      ...> |> Blockchain.Account.get_accounts([sender, beneficiary, contract_address])
      [%Blockchain.Account{balance: 238727, nonce: 6}, %Blockchain.Account{balance: 161268}, %Blockchain.Account{balance: 5, code_hash: <<243, 247, 169, 254, 54, 79, 170, 185, 59, 33, 109, 165, 10, 50, 20, 21, 79, 34, 160, 162, 180, 21, 178, 58, 132, 200, 22, 158, 139, 99, 110, 227>>}]
  """
  @spec add_transactions_to_block(t, [Transaction.t], DB.db) :: t
  def add_transactions_to_block(block, transactions, db) do
    trx_count = get_transaction_count(block)

    do_add_transactions_to_block(block, transactions, db, trx_count)
  end

  @spec do_add_transactions_to_block(t, [Transaction.t], DB.db, integer()) :: t
  defp do_add_transactions_to_block(block, [], _, _), do: block
  defp do_add_transactions_to_block(block=%__MODULE__{header: header}, [trx|transactions], db, trx_count) do
    state = MerklePatriciaTree.Trie.new(db, header.state_root)
    # TODO: How do we deal with invalid transactions
    {new_state, gas_used, logs} = Blockchain.Transaction.execute_transaction(state, trx, header)

    total_gas_used = block.header.gas_used + gas_used

    receipt = %Blockchain.Transaction.Receipt{state: new_state.root_hash, cumulative_gas: total_gas_used, logs: logs} # TODO: Add bloom filter

    updated_block =
      block
      |> put_state(new_state)
      |> put_gas_used(total_gas_used)
      |> put_receipt(trx_count, receipt, db)
      |> put_transaction(trx_count, trx, db)

    do_add_transactions_to_block(updated_block, transactions, db, trx_count + 1)
  end

  # Updates a block to have a new state root given a state object
  @spec put_state(t, EVM.state) :: t
  defp put_state(block=%__MODULE__{header: header}, new_state) do
    %{block | header: %{header | state_root: new_state.root_hash}}
  end

  # Updates a block to have total gas used set in the header
  @spec put_gas_used(t, EVM.Gas.t) :: t
  defp put_gas_used(block=%__MODULE__{header: header}, gas_used) do
    %{block | header: %{header | gas_used: gas_used}}
  end

  @doc """
  Updates a block by adding a receipt to the list of receipts
  at position `i`.

  ## Examples

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> block = Blockchain.Block.put_receipt(%Blockchain.Block{}, 5, %Blockchain.Transaction.Receipt{state: <<1, 2, 3>>, cumulative_gas: 10, bloom_filter: <<2, 3, 4>>, logs: "hi mom"}, db)
      iex> MerklePatriciaTree.Trie.new(db, block.header.receipts_root)
      ...> |> MerklePatriciaTree.Trie.Inspector.all_values()
      [{<<5>>, <<208, 131, 1, 2, 3, 10, 131, 2, 3, 4, 134, 104, 105, 32, 109, 111, 109>>}]
  """
  @spec put_receipt(t, integer(), Receipt.t, DB.db) :: t
  def put_receipt(block, i, receipt, db) do
    updated_receipts_root =
      Trie.new(db, block.header.receipts_root)
      |> Trie.update(ExRLP.encode(i), Receipt.serialize(receipt) |> ExRLP.encode)

    %{block | header: %{block.header | receipts_root: updated_receipts_root.root_hash}}
  end

  @doc """
  Updates a block by adding a transaction to the list of transactions
  and updating the transactions_root in the header at position `i`, which
  should be equilvant to the current number of transactions.

  ## Examples

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> block = Blockchain.Block.put_transaction(%Blockchain.Block{}, 0, %Blockchain.Transaction{nonce: 1, v: 2, r: 3, s: 4}, db)
      iex> block.transactions
      [%Blockchain.Transaction{nonce: 1, v: 2, r: 3, s: 4}]
      iex> MerklePatriciaTree.Trie.new(db, block.header.transactions_root)
      ...> |> MerklePatriciaTree.Trie.Inspector.all_values()
      [{<<0x80>>, <<201, 1, 128, 128, 128, 128, 128, 2, 3, 4>>}]
  """
  @spec put_transaction(t, integer(), Transaction.t, DB.db) :: t
  def put_transaction(block, i, trx, db) do
    total_transactions =  block.transactions ++ [trx]
    updated_transactions_root =
      Trie.new(db, block.header.transactions_root)
      |> Trie.update(ExRLP.encode(i), Transaction.serialize(trx) |> ExRLP.encode)

    %{block | transactions: total_transactions, header: %{block.header | transactions_root: updated_transactions_root.root_hash}}
  end

end