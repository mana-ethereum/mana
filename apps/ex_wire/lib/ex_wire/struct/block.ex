defmodule ExWire.Struct.Block do
  @moduledoc """
  A struct for storing blocks as they are transported over the Eth Wire
  Protocol.
  """

  alias Block.Header
  alias Blockchain.Transaction

  defstruct [
    :transactions_rlp,
    :transactions,
    :ommers_rlp,
    :ommers
  ]

  @type t :: %__MODULE__{
          transactions_rlp: list(binary()),
          transactions: list(Transaction.t()),
          ommers_rlp: list(binary()),
          ommers: list(Header.t())
        }

  @doc """
  Given a Block, serializes for transport over Eth Wire Protocol.

  ## Examples

      iex> %ExWire.Struct.Block{
      ...>   transactions_rlp: [[<<5>>, <<6>>, <<7>>, <<1::160>>, <<8>>, "hi", <<27>>, <<9>>, <<10>>]],
      ...>   ommers_rlp: [[<<1::256>>, <<2::256>>, <<3::160>>, <<4::256>>, <<5::256>>, <<6::256>>, <<>>, <<5>>, <<1>>, <<5>>, <<3>>, <<6>>, "Hi mom", <<7::256>>, <<8::64>>]]
      ...> }
      ...> |> ExWire.Struct.Block.serialize
      [[[<<5>>, <<6>>, <<7>>, <<1::160>>, <<8>>, "hi", <<27>>, <<9>>, <<10>>]], [[<<1::256>>, <<2::256>>, <<3::160>>, <<4::256>>, <<5::256>>, <<6::256>>, <<>>, <<5>>, <<1>>, <<5>>, <<3>>, <<6>>, "Hi mom", <<7::256>>, <<8::64>>]]]
  """
  @spec serialize(t) :: ExRLP.t()
  def serialize(struct) do
    [
      struct.transactions_rlp,
      struct.ommers_rlp
    ]
  end

  @doc """
  Given an RLP-encoded block from Eth Wire Protocol, decodes into a `Block` struct.

  ## Examples

      iex> ExWire.Struct.Block.deserialize([[[<<5>>, <<6>>, <<7>>, <<1::160>>, <<8>>, "hi", <<27>>, <<9>>, <<10>>]], [[<<1::256>>, <<2::256>>, <<3::160>>, <<4::256>>, <<5::256>>, <<6::256>>, <<>>, <<5>>, <<1>>, <<5>>, <<3>>, <<6>>, "Hi mom", <<7::256>>, <<8::64>>]]])
      %ExWire.Struct.Block{
        transactions_rlp: [[<<5>>, <<6>>, <<7>>, <<1::160>>, <<8>>, "hi", <<27>>, <<9>>, <<10>>]],
        transactions: [%Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1::160>>, value: 8, v: 27, r: 9, s: 10, data: "hi"}],
        ommers_rlp: [[<<1::256>>, <<2::256>>, <<3::160>>, <<4::256>>, <<5::256>>, <<6::256>>, <<>>, <<5>>, <<1>>, <<5>>, <<3>>, <<6>>, "Hi mom", <<7::256>>, <<8::64>>]],
        ommers: [%Block.Header{parent_hash: <<1::256>>, ommers_hash: <<2::256>>, beneficiary: <<3::160>>, state_root: <<4::256>>, transactions_root: <<5::256>>, receipts_root: <<6::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<7::256>>, nonce: <<8::64>>}]
      }
  """
  @spec deserialize(ExRLP.t()) :: t
  def deserialize(rlp) do
    [
      transactions_rlp,
      ommers_rlp
    ] = rlp

    %__MODULE__{
      transactions_rlp: transactions_rlp,
      transactions: Enum.map(transactions_rlp, &Transaction.deserialize/1),
      ommers_rlp: ommers_rlp,
      ommers: Enum.map(ommers_rlp, &Header.deserialize/1)
    }
  end
end
