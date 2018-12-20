defmodule JSONRPC2.Response.Transaction do
  alias Blockchain.Transaction
  alias Blockchain.Transaction.Signature

  import JSONRPC2.Response.Helpers

  @derive Jason.Encoder
  defstruct [
    :blockHash,
    :blockNumber,
    :from,
    :gas,
    :gasPrice,
    :hash,
    :input,
    :nonce,
    :to,
    :transactionIndex,
    :value,
    :v,
    :r,
    :s
  ]

  @type t :: %__MODULE__{
          blockHash: binary(),
          blockNumber: binary(),
          from: binary(),
          gas: binary(),
          gasPrice: binary(),
          hash: binary(),
          input: binary(),
          nonce: binary(),
          to: binary(),
          transactionIndex: binary(),
          value: binary(),
          v: binary(),
          r: binary(),
          s: binary()
        }

  @spec new(Blockchain.Transaction.t(), Blockchain.Block.t(), integer() | nil) :: t()
  def new(internal_transaction, internal_block, network_id \\ nil) do
    %__MODULE__{
      blockHash: encode_unformatted_data(internal_block.block_hash),
      blockNumber: encode_quantity(internal_block.header.number),
      from: from_address(internal_transaction, network_id),
      gas: encode_quantity(internal_transaction.gas_limit),
      gasPrice: encode_quantity(internal_transaction.gas_price),
      hash: hash(internal_transaction),
      input: internal_transaction |> Transaction.input_data() |> encode_unformatted_data,
      nonce: encode_quantity(internal_transaction.nonce),
      to: encode_unformatted_data(internal_transaction.to),
      transactionIndex: transaction_index(internal_transaction, internal_block),
      value: encode_quantity(internal_transaction.value),
      v: encode_quantity(internal_transaction.v),
      r: encode_quantity(internal_transaction.r),
      s: encode_quantity(internal_transaction.s)
    }
  end

  defp transaction_index(internal_transaction, internal_block) do
    index =
      Enum.find_index(internal_block.transactions, fn block_transaction ->
        block_transaction == internal_transaction
      end)

    encode_quantity(index)
  end

  defp hash(internal_transaction) do
    internal_transaction
    |> Signature.transaction_hash()
    |> encode_unformatted_data()
  end

  defp from_address(internal_transaction, network_id) do
    {:ok, sender} = Signature.sender(internal_transaction, network_id)

    encode_unformatted_data(sender)
  end
end
