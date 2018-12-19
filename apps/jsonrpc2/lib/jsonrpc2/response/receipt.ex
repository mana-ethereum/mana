defmodule JSONRPC2.Response.Receipt do
  alias Blockchain.Transaction

  alias Blockchain.Account.Address
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
    sender = from_address(transaction, network_id)
    transaction_hash = transaction_hash(transaction)

    %__MODULE__{
      transactionHash: transaction_hash,
      transactionIndex: encode_hex(index),
      blockHash: encode_hex(block.block_hash),
      blockNumber: encode_hex(block.header.number),
      from: encode_hex(sender),
      to: encode_hex(transaction.to),
      cumulativeGasUsed: encode_hex(receipt.cumulative_gas),
      gasUsed: calculate_gas_used(block, index, receipt),
      contractAddress: new_contract_address(transaction, sender),
      logs: format_logs(receipt, index, transaction_hash, block),
      logsBloom: encode_hex(receipt.bloom_filter),
      status: encode_hex(receipt.state)
    }
  end

  defp transaction_hash(transaction) do
    transaction
    |> Signature.transaction_hash()
    |> encode_hex()
  end

  defp transaction_index(transaction, block) do
    block.transactions
    |> Enum.find_index(fn trx -> trx == transaction end)
  end

  defp from_address(internal_transaction, network_id) do
    {:ok, sender} = Signature.sender(internal_transaction, network_id)

    sender
  end

  defp calculate_gas_used(block, index, receipt) do
    result =
      cond do
        Enum.count(block.receipts) <= 1 ->
          receipt.cumulative_gas

        index == 0 ->
          receipt.cumulative_gas

        true ->
          previous_receipt = Enum.at(block.receipts, index - 1)

          receipt.cumulative_gas - previous_receipt.cumulative_gas
      end

    encode_hex(result)
  end

  defp new_contract_address(transaction, sender) do
    result =
      if Transaction.contract_creation?(transaction) do
        Address.new(sender, transaction.nonce)
      end

    encode_hex(result)
  end

  defp format_logs(receipt, transaction_index, transaction_hash, block) do
    prev_logs_count =
      block.receipts
      |> Enum.take(transaction_index)
      |> Enum.flat_map(fn receipt -> receipt.logs end)
      |> Enum.count()

    {_, result} =
      receipt.logs
      |> Enum.reduce({prev_logs_count, []}, fn log, {current_log_index, acc} ->
        current_log = %{
          removed: false,
          logIndex: encode_hex(current_log_index),
          transactionIndex: encode_hex(transaction_index),
          transactionHash: encode_hex(transaction_hash),
          blockHash: encode_hex(block.block_hash),
          blockNumber: encode_hex(block.header.number),
          address: encode_hex(log.address),
          data: encode_hex(log.data),
          topics: Enum.map(log.topics, fn topic -> encode_hex(topic) end)
        }

        {current_log_index + 1, acc ++ [current_log]}
      end)

    result
  end
end
