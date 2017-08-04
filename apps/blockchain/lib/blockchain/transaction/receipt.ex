defmodule Blockchain.Transaction.Receipt do
  @moduledoc """
  This module specifies functions to create and
  interact with the transaction receipt, defined
  in Section 4.4.1 of the Yellow Paper.

  Transaction receipts track incremental state changes
  after each transaction (e.g. how much gas has been
  expended).
  """

  # Defined in Eq.(19)
  defstruct [
    state: <<>>,
    cumulative_gas: 0,
    bloom_filter: <<>>,
    logs: <<>>,
  ]

  # Types defined in Eq.(20)
  @type t :: %{
    state: EVM.state,
    cumulative_gas: EVM.Gas.t, # Defined in Eq.(21)
    bloom_filter: <<>>, # TODO: Bloom filter
    logs: EVM.SubState.logs,
  }

  @doc """
  Encodes a transaction receipt such that it can be
  RLP encoded. This is defined in Eq.(20) of the Yellow
  Paper.

  ## Examples

      iex> Blockchain.Transaction.Receipt.serialize(%Blockchain.Transaction.Receipt{})
      [<<>>, 0, <<>>, <<>>]

      iex> Blockchain.Transaction.Receipt.serialize(%Blockchain.Transaction.Receipt{state: <<1,2,3>>, cumulative_gas: 5, bloom_filter: <<2,3,4>>, logs: "hi mom"})
      [<<1,2,3>>, 5, <<2,3,4>>, "hi mom"]
  """
  @spec serialize(t) :: ExRLP.t
  def serialize(trx_receipt) do
    [
      trx_receipt.state,
      trx_receipt.cumulative_gas,
      trx_receipt.bloom_filter,
      trx_receipt.logs,
    ]
  end

  @doc """
  Decodes a transaction receipt based on the serialization format
  defined in Eq.(20). This is the inverse of `serialize/1`.

  ## Examples

    iex> Blockchain.Transaction.Receipt.deserialize([<<1,2,3>>, <<5>>, <<2,3,4>>, "hi mom"])
    %Blockchain.Transaction.Receipt{state: <<1,2,3>>, cumulative_gas: 5, bloom_filter: <<2,3,4>>, logs: "hi mom"}

    iex> Blockchain.Transaction.Receipt.deserialize([<<>>, <<0>>, <<>>, <<>>])
    %Blockchain.Transaction.Receipt{}
  """
  @spec deserialize(ExRLP.t) :: t
  def deserialize(rlp) do
    [
      state,
      cumulative_gas,
      bloom_filter,
      logs
    ] = rlp

    %Blockchain.Transaction.Receipt{
      state: state,
      cumulative_gas: :binary.decode_unsigned(cumulative_gas),
      bloom_filter: bloom_filter,
      logs: logs
    }
  end

end