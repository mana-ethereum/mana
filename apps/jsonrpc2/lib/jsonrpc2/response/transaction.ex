defmodule JSONRPC2.Response.Transaction do
  alias Blockchain.Transaction
  alias Blockchain.Transaction.Signature
  alias ExthCrypto.Hash.Keccak

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

  def new(internal_transaction, internal_block, network_id \\ nil) do
    %__MODULE__{
      blockHash: encode_hex(internal_block.block_hash),
      blockNumber: encode_hex(internal_block.header.number),
      from: from_address(internal_transaction, network_id),
      gas: encode_hex(internal_transaction.gas_limit),
      gasPrice: encode_hex(internal_transaction.gas_price),
      hash: hash(internal_transaction),
      input: internal_transaction |> Transaction.input_data() |> encode_hex,
      nonce: encode_hex(internal_transaction.nonce),
      to: encode_hex(internal_transaction.to),
      transactionIndex: transaction_index(internal_transaction, internal_block),
      value: encode_hex(internal_transaction.value),
      v: encode_hex(internal_transaction.v),
      r: encode_hex(internal_transaction.r),
      s: encode_hex(internal_transaction.s)
    }
  end

  defp transaction_index(internal_transaction, internal_block) do
    index =
      Enum.find_index(internal_block.transactions, fn block_transaction ->
        block_transaction == internal_transaction
      end)

    encode_hex(index)
  end

  defp hash(internal_transaction) do
    internal_transaction
    |> Transaction.serialize()
    |> ExRLP.encode()
    |> Keccak.kec()
    |> encode_hex
  end

  defp from_address(internal_transaction, network_id) do
    {:ok, sender} = Signature.sender(internal_transaction, network_id)

    encode_hex(sender)
  end
end
