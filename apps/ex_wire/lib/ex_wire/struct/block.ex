defmodule ExWire.Struct.Block do
  @moduledoc """
  A struct for storing blocks as they are transported over the Eth Wire Protocol.
  """

  defstruct [
    :transactions_list,
    :transactions,
    :ommers
  ]

  @type t :: %__MODULE__{
    transactions: [Blockchain.Transaction.t],
    ommers: [binary()]
  }

  @doc """
  Given a Block, serializes for transport over Eth Wire Protocol.

  ## Examples

      iex> %ExWire.Struct.Block{transactions_list: [[<<5>>, <<6>>, <<7>>, <<1::160>>, <<8>>, "hi", <<27>>, <<9>>, <<10>>]], ommers: [<<1::256>>]}
      ...> |> ExWire.Struct.Block.serialize
      [[[<<5>>, <<6>>, <<7>>, <<1::160>>, <<8>>, "hi", <<27>>, <<9>>, <<10>>]], [<<1::256>>]]
  """
  @spec serialize(t) :: ExRLP.t
  def serialize(struct) do
    [
      struct.transactions_list,
      struct.ommers
    ]
  end

  @doc """
  Given an RLP-encoded block from Eth Wire Protocol, decodes into a Block struct.

  ## Examples

      iex> ExWire.Struct.Block.deserialize([[[<<5>>, <<6>>, <<7>>, <<1::160>>, <<8>>, "hi", <<27>>, <<9>>, <<10>>]], [<<1::256>>]])
      %ExWire.Struct.Block{
        transactions_list: [[<<5>>, <<6>>, <<7>>, <<1::160>>, <<8>>, "hi", <<27>>, <<9>>, <<10>>]],
        transactions: [%Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1::160>>, value: 8, v: 27, r: 9, s: 10, data: "hi"}],
        ommers: [<<1::256>>]
      }
  """
  @spec deserialize(ExRLP.t) :: t
  def deserialize(rlp) do
    [
      transactions_list,
      ommers
    ] = rlp

    %__MODULE__{
      transactions_list: transactions_list,
      transactions: ( for transaction_rlp <- transactions_list, do: Blockchain.Transaction.deserialize(transaction_rlp) ),
      ommers: ommers
    }
  end

end