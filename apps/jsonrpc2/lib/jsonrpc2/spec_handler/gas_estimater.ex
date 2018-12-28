defmodule JSONRPC2.SpecHandler.GasEstimater do
  alias Blockchain.Block
  alias Blockchain.Transaction
  alias MerklePatriciaTree.TrieStorage

  @max_gas_limit 50_000_000

  def run(state, call_request, block_number, chain) do
    with {:ok, block} <- find_block(state, block_number) do
      transaction = transaction_from_call_request(call_request)

      lower_limit = Transaction.intrinsic_gas_cost(transaction, chain.evm_config)
      upper_limit = transaction.gas_limit * 10

      with {:ok, _gas} <- estimate_gas(state, transaction, upper_limit, block.header, chain) do
        case estimate_gas(state, transaction, lower_limit, block.header, chain) do
          {:ok, gas} -> {:ok, gas}
          _ -> find_estimate(state, transaction, lower_limit, upper_limit, block.header, chain)
        end
      end
    end
  end

  defp transaction_from_call_request(call_request) do
    gas_limit = call_request.gas || @max_gas_limit
    value = call_request.value || 0
    data = call_request.data || <<>>
    gas_price = call_request.gas_price || 0
    to = call_request.to || <<>>
    from = call_request.from || <<>>

    %Transaction{
      gas_price: gas_price,
      gas_limit: gas_limit,
      data: data,
      value: value,
      to: to,
      from: from
    }
  end

  defp find_estimate(_state, _transaction, lower_limit, upper_limit, _block_header, _chain)
       when upper_limit - lower_limit <= 1 do
    {:ok, upper_limit}
  end

  defp find_estimate(state, transaction, lower_limit, upper_limit, block_header, chain) do
    middle = (upper_limit + lower_limit) / 2

    {lower_limit, upper_limit} =
      case estimate_gas(state, transaction, middle, block_header, chain) do
        {:ok, _} -> {lower_limit, middle}
        _ -> {middle, upper_limit}
      end

    find_estimate(state, transaction, lower_limit, upper_limit, block_header, chain)
  end

  defp find_block(state, block_number) do
    case Block.get_block(block_number, state) do
      {:ok, block} -> {:ok, block}
      _ -> {:error, "Block is not found"}
    end
  end

  defp estimate_gas(state, transaction, gas, block_header, chain) do
    transaction = %{transaction | gas_limit: gas}

    {repo, gas_used, _receipt} =
      Transaction.execute_with_validation(state, transaction, block_header, chain)

    if TrieStorage.root_hash(repo.state) == TrieStorage.root_hash(state) do
      {:error, "Transaction failed with provided gas #{gas}"}
    else
      {:ok, gas_used}
    end
  end
end
