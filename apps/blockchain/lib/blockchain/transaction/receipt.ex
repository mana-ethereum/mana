defmodule Blockchain.Transaction.Receipt do
  use Bitwise
  alias Blockchain.Transaction.Receipt.Bloom

  @moduledoc """
  This module specifies functions to create and
  interact with the transaction receipt, defined
  in Section 4.3.1 of the Yellow Paper.

  Transaction receipts track incremental state changes
  after each transaction (e.g. how much gas has been
  expended).

  When a block is generated or verified, the contract addresses and fields from the generated logs are added to a bloom filter. This is included in the block header.

  _From Yellow Paper 4.3.1. Transaction Receipt_: The transaction receipt (R) is a tuple of four items comprising the post-transaction state:

   - _Ru:_ the cumulative gas used in the block containing the transaction receipt immediately after the transaction has happened

   - _Rl:_ the set of logs created through execution of the transaction

   - _Rb_: the *bloom filter* composed from information in those logs

   - _Rz_: the status code of the transaction.

   Update:
   Receipts contain root hash before Byzantium and 0 (or 1) after as per https://github.com/ethereum/EIPs/blob/master/EIPS/eip-658.md
  """

  # Defined in Eq.(20)
  defstruct state: <<>>,
            cumulative_gas: 0,
            bloom_filter: :binary.list_to_bin(Bloom.empty()),
            logs: []

  # Types defined in Eq.(22) and Eq.(23)
  @type t :: %__MODULE__{
          state: state,
          # Defined in Eq.(21)
          cumulative_gas: EVM.Gas.t(),
          # Defined in Eq.(26)
          bloom_filter: binary(),
          logs: EVM.SubState.logs()
        }
  @type state :: EVM.trie_root() | 0 | 1
  @spec new(state, EVM.Gas.t(), EVM.SubState.logs()) :: t()
  def new(state_root, gas_used, logs) do
    bloom_filter = Bloom.from_logs(logs)

    %__MODULE__{
      state: state_root,
      cumulative_gas: gas_used,
      bloom_filter: bloom_filter,
      logs: logs
    }
  end

  @doc """
  Encodes a transaction receipt such that it can be
  RLP encoded. This is defined in Eq.(21) of the Yellow
  Paper.

  ## Examples

      iex> Blockchain.Transaction.Receipt.serialize(%Blockchain.Transaction.Receipt{})
      [<<>>, 0, 0 |> List.duplicate(256) |> :binary.list_to_bin(), []]

      iex> Blockchain.Transaction.Receipt.serialize(%Blockchain.Transaction.Receipt{state: <<1,2,3>>, cumulative_gas: 5, bloom_filter: <<2,3,4>>, logs: []})
      [<<1,2,3>>, 5, <<2,3,4>>, []]
  """
  @spec serialize(t) :: ExRLP.t()
  def serialize(trx_receipt) do
    [
      trx_receipt.state,
      trx_receipt.cumulative_gas,
      trx_receipt.bloom_filter,
      trx_receipt.logs
    ]
  end

  @doc """
  Decodes a transaction receipt based on the serialization format
  defined in Eq.(21). This is the inverse of `serialize/1`.

  ## Examples

    iex> Blockchain.Transaction.Receipt.deserialize([<<1,2,3>>, <<5>>, <<2,3,4>>, []])
    %Blockchain.Transaction.Receipt{state: <<1,2,3>>, cumulative_gas: 5, bloom_filter: <<2,3,4>>, logs: []}

    iex> Blockchain.Transaction.Receipt.deserialize([<<>>, <<0>>, 0 |> List.duplicate(256) |> :binary.list_to_bin(), []])
    %Blockchain.Transaction.Receipt{}
  """
  @spec deserialize(ExRLP.t()) :: t
  def deserialize(rlp) do
    [
      state,
      cumulative_gas,
      bloom_filter,
      raw_logs
    ] = rlp

    logs =
      Enum.map(raw_logs, fn [address, topics, data] -> EVM.LogEntry.new(address, topics, data) end)

    %__MODULE__{
      state: state,
      cumulative_gas: Exth.maybe_decode_unsigned(cumulative_gas),
      bloom_filter: bloom_filter,
      logs: logs
    }
  end
end
