defmodule JSONRPC2.Response.Receipt do
  alias Blockchain.Transaction
  alias Blockchain.Transaction.Signature

  import JSONRPC2.Response.Helpers

  @derive Jason.Encoder
  defstruct [
    :transactionHash,
    :transactionIndex,
    :blockHash,
    :blockNumber,
    :from,
    :to,
    :cumulativeGasUsed,
    :gasUsed,
    :contractAddress,
    :logs,
    :logsBloom,
    :root,
    :status
  ]

  @type t :: %__MODULE__{
          transactionHash: binary(),
          transactionIndex: binary(),
          blockHash: binary(),
          blockNumber: binary(),
          from: binary(),
          to: binary(),
          cumulativeGasUsed: binary(),
          gasUsed: binary(),
          contractAddress: binary(),
          logs: [],
          logsBloom: binary(),
          root: binary(),
          status: binary()
        }

  def new(receipt, transaction, block, network_id \\ nil) do
    index = transaction_index(transaction, block)

    %__MODULE__{
      transactionHash: transaction_hash(transaction),
      transactionIndex: encode_hex(index),
      blockHash: encode_hex(block.block_hash),
      blockNumber: encode_hex(block.header.number),
      from: from_address(transaction, network_id),
      to: encode_hex(transaction.to),
      cumulativeGasUsed: encode_hex(receipt.cumulative_gas),
      gasUsed: calculate_gas_used(block, index, receipt),
      contractAddress: "",
      logs: [],
      logsBloom: encode_hex(receipt.bloom_filter),
      status: encode_hex(receipt.state)
    }
  end

  defp transaction_hash(transaction) do
    transaction
    |> Transaction.hash()
    |> encode_hex()
  end

  defp transaction_index(transaction, block) do
    block.transactions
    |> Enum.find_index(fn trx -> trx == transaction end)
  end

  defp from_address(internal_transaction, network_id) do
    {:ok, sender} = Signature.sender(internal_transaction, network_id)

    encode_hex(sender)
  end

  defp calculate_gas_used(block, index, receipt) do
    result =
      cond do
        Enum.count(block.receipts) <= 1 ->
          receipt.cumulative_gas

        index == 0 ->
          receipt.cumulative_gas

        true ->
          previous_cumulative_gas = Enum.at(block.receipts, index - 1)

          receipt.cumulative_gas - previous_cumulative_gas
      end

    encode_hex(result)
  end
end
