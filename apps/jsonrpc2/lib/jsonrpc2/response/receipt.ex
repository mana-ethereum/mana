defmodule JSONRPC2.Response.Receipt do
  alias Blockchain.Transaction

  alias Blockchain.Account.Address
  alias Blockchain.Block
  alias Blockchain.Transaction
  alias Blockchain.Transaction.Receipt
  alias Blockchain.Transaction.Signature
  alias JSONRPC2.Response.Receipt.ByzantiumReceipt
  alias JSONRPC2.Response.Receipt.PreByzantiumReceipt

  import JSONRPC2.Response.Helpers

  @type logs :: [
          %{
            removed: boolean(),
            logIndex: binary(),
            transactionIndex: binary(),
            transactionHash: binary(),
            blockHash: binary(),
            blockNumber: binary(),
            address: binary(),
            data: binary(),
            topics: [binary()]
          }
        ]

  defmodule PreByzantiumReceipt do
    alias JSONRPC2.Response.Receipt

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
      :root
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
            contractAddress: binary() | nil,
            logs: Receipt.logs(),
            logsBloom: binary(),
            root: binary()
          }
  end

  defmodule ByzantiumReceipt do
    alias JSONRPC2.Response.Receipt

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
            contractAddress: binary() | nil,
            logs: Receipt.logs(),
            logsBloom: binary(),
            status: binary()
          }
  end

  @type t :: ByzantiumReceipt.t() | PreByzantiumReceipt.t()

  @spec new(Receipt.t(), Transaction.t(), Block.t(), integer() | nil) :: t()
  def new(receipt, transaction, block, network_id \\ nil) do
    index = transaction_index(transaction, block)
    sender = from_address(transaction, network_id)
    transaction_hash = transaction_hash(transaction)

    params = %{
      transactionHash: transaction_hash,
      transactionIndex: encode_quantity(index),
      blockHash: encode_unformatted_data(block.block_hash),
      blockNumber: encode_quantity(block.header.number),
      from: encode_unformatted_data(sender),
      to: encode_unformatted_data(transaction.to),
      cumulativeGasUsed: encode_quantity(receipt.cumulative_gas),
      gasUsed: calculate_gas_used(block, index, receipt),
      contractAddress: new_contract_address(transaction, sender),
      logs: format_logs(receipt, index, transaction_hash, block),
      logsBloom: encode_unformatted_data(receipt.bloom_filter)
    }

    if is_integer(receipt.state) do
      params = Map.put(params, :status, encode_quantity(receipt.state))

      struct(JSONRPC2.Response.Receipt.ByzantiumReceipt, params)
    else
      params = Map.put(params, :root, encode_unformatted_data(receipt.state))

      struct(JSONRPC2.Response.Receipt.PreByzantiumReceipt, params)
    end
  end

  defp transaction_hash(transaction) do
    transaction
    |> Signature.transaction_hash()
    |> encode_unformatted_data()
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

    encode_quantity(result)
  end

  defp new_contract_address(transaction, sender) do
    result =
      if Transaction.contract_creation?(transaction) do
        Address.new(sender, transaction.nonce)
      end

    encode_unformatted_data(result)
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
          logIndex: encode_quantity(current_log_index),
          transactionIndex: encode_quantity(transaction_index),
          transactionHash: encode_unformatted_data(transaction_hash),
          blockHash: encode_unformatted_data(block.block_hash),
          blockNumber: encode_quantity(block.header.number),
          address: encode_unformatted_data(log.address),
          data: encode_unformatted_data(log.data),
          topics: Enum.map(log.topics, fn topic -> encode_unformatted_data(topic) end)
        }

        {current_log_index + 1, acc ++ [current_log]}
      end)

    result
  end
end
