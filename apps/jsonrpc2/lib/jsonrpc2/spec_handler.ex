defmodule JSONRPC2.SpecHandler do
  use JSONRPC2.Server.Handler

  alias ExthCrypto.Hash.Keccak
  alias JSONRPC2.Bridge.Sync
  alias JSONRPC2.Struct.EthSyncing
  @sync Application.get_env(:jsonrpc2, :bridge_mock, Sync)
  # web3 Methods

  def handle_request("web3_clientVersion", _),
    do: Application.get_env(:jsonrpc2, :mana_version)

  def handle_request("web3_sha3", [param]) do
    param
    |> Exth.decode_hex()
    |> Keccak.kec()
    |> Exth.encode_hex()
  rescue
    _ ->
      {:error, :invalid_params}
  end

  # net Methods
  def handle_request("net_version", _), do: "#{Application.get_env(:ex_wire, :network_id)}"
  def handle_request("net_listening", _), do: Application.get_env(:ex_wire, :discovery)

  def handle_request("net_peerCount", _) do
    connected_peer_count = @sync.connected_peer_count()

    Exth.encode_unsigned_hex(connected_peer_count)
  end

  # eth Methods
  def handle_request("eth_protocolVersion", _), do: {:error, :not_supported}

  def handle_request("eth_syncing", _) do
    case @sync.get_last_sync_block_stats() do
      {_current_block_header_number, _starting_block, _highest_block} = params ->
        EthSyncing.output(params)

      false ->
        false
    end
  end

  def handle_request("eth_coinbase", _), do: {:error, :not_supported}
  def handle_request("eth_mining", _), do: {:error, :not_supported}
  def handle_request("eth_hashrate", _), do: {:error, :not_supported}
  def handle_request("eth_gasPrice", _), do: {:error, :not_supported}
  def handle_request("eth_accounts", _), do: {:error, :not_supported}

  def handle_request("eth_blockNumber", _) do
    {current_block_header_number, _starting_block, _highest_block} =
      @sync.get_last_sync_block_stats()

    current_block_header_number
  end

  def handle_request("eth_getBalance", [hex_address, hex_number_or_tag]) do
    block_number = decode_block_number(hex_number_or_tag)

    address = Exth.decode_hex(hex_address)

    @sync.get_balance(address, block_number)
  end

  def handle_request("eth_getStorageAt", _), do: {:error, :not_supported}
  def handle_request("eth_getTransactionCount", _), do: {:error, :not_supported}

  def handle_request("eth_getBlockTransactionCountByHash", [block_hash_hex]) do
    block_hash_hex
    |> Exth.decode_hex()
    |> @sync.get_block_transaction_count_by_hash()
  end

  def handle_request("eth_getBlockTransactionCountByNumber", [block_number_hex]) do
    block_number_hex
    |> Exth.decode_unsigned_from_hex()
    |> @sync.get_block_transaction_count_by_number()
  end

  def handle_request("eth_getUncleCountByBlockHash", [block_hash_hex]) do
    block_hash_hex
    |> Exth.decode_hex()
    |> @sync.get_uncle_count_by_block_hash()
  end

  def handle_request("eth_getUncleCountByBlockNumber", [block_number_hex]) do
    block_number_hex
    |> Exth.decode_unsigned_from_hex()
    |> @sync.get_uncle_count_by_block_number()
  end

  def handle_request("eth_getCode", [hex_address, hex_number_or_tag]) do
    block_number = decode_block_number(hex_number_or_tag)

    address = Exth.decode_hex(hex_address)

    @sync.get_code(address, block_number)
  end

  def handle_request("eth_sign", _), do: {:error, :not_supported}
  def handle_request("eth_sendTransaction", _), do: {:error, :not_supported}
  def handle_request("eth_sendRawTransaction", _), do: {:error, :not_supported}
  def handle_request("eth_call", _), do: {:error, :not_supported}
  def handle_request("eth_estimateGas", _), do: {:error, :not_supported}

  def handle_request("eth_getBlockByHash", [hash, include_full_transactions]) do
    hash
    |> Exth.decode_hex()
    |> @sync.get_block_by_hash(include_full_transactions)
  end

  def handle_request("eth_getBlockByNumber", [number_hex, include_full_transactions]) do
    number = Exth.decode_unsigned_from_hex(number_hex)

    @sync.get_block_by_number(number, include_full_transactions)
  end

  def handle_request("eth_getTransactionByHash", _), do: {:error, :not_supported}

  def handle_request("eth_getTransactionByBlockHashAndIndex", [
        block_hash_hex,
        transaction_index_hex
      ]) do
    block_hash = Exth.decode_hex(block_hash_hex)
    transaction_index = Exth.decode_unsigned_from_hex(transaction_index_hex)

    @sync.get_transaction_by_block_hash_and_index(block_hash, transaction_index)
  end

  def handle_request("eth_getTransactionByBlockNumberAndIndex", [
        block_number_hex,
        transaction_index_hex
      ]) do
    block_number = Exth.decode_unsigned_from_hex(block_number_hex)
    transaction_index = Exth.decode_unsigned_from_hex(transaction_index_hex)

    @sync.get_transaction_by_block_number_and_index(block_number, transaction_index)
  end

  def handle_request("eth_getTransactionReceipt", _), do: {:error, :not_supported}
  def handle_request("eth_getUncleByBlockHashAndIndex", _), do: {:error, :not_supported}
  def handle_request("eth_getUncleByBlockNumberAndIndex", _), do: {:error, :not_supported}
  # eth_getCompilers is deprecated
  def handle_request("eth_getCompilers", _), do: {:error, :not_supported}
  # eth_compileLLL is deprecated
  def handle_request("eth_compileLLL", _), do: {:error, :not_supported}
  # eth_compileSolidity is deprecated
  def handle_request("eth_compileSolidity", _), do: {:error, :not_supported}
  # eth_compileSerpent is deprecated
  def handle_request("eth_compileSerpent", _), do: {:error, :not_supported}
  def handle_request("eth_newFilter", _), do: {:error, :not_supported}
  def handle_request("eth_newBlockFilter", _), do: {:error, :not_supported}
  def handle_request("eth_newPendingTransactionFilter", _), do: {:error, :not_supported}
  def handle_request("eth_uninstallFilter", _), do: {:error, :not_supported}
  def handle_request("eth_getFilterChanges", _), do: {:error, :not_supported}
  def handle_request("eth_getFilterLogs", _), do: {:error, :not_supported}
  def handle_request("eth_getLogs", _), do: {:error, :not_supported}
  def handle_request("eth_getWork", _), do: {:error, :not_supported}
  def handle_request("eth_submitWork", _), do: {:error, :not_supported}
  def handle_request("eth_submitHashrate", _), do: {:error, :not_supported}
  def handle_request("eth_getProof", _), do: {:error, :not_supported}
  # db_putString is deprecated
  def handle_request("db_putString", _), do: {:error, :not_supported}
  # db_getString is deprecated
  def handle_request("db_getString", _), do: {:error, :not_supported}
  # db_putHex is deprecated
  def handle_request("db_putHex", _), do: {:error, :not_supported}
  # db_getHex is deprecated
  def handle_request("db_getHex", _), do: {:error, :not_supported}
  def handle_request("shh_post", _), do: {:error, :not_supported}
  def handle_request("shh_version", _), do: {:error, :not_supported}
  def handle_request("shh_newIdentity", _), do: {:error, :not_supported}
  def handle_request("shh_hasIdentity", _), do: {:error, :not_supported}
  def handle_request("shh_newGroup", _), do: {:error, :not_supported}
  def handle_request("shh_addToGroup", _), do: {:error, :not_supported}
  def handle_request("shh_newFilter", _), do: {:error, :not_supported}
  def handle_request("shh_uninstallFilter", _), do: {:error, :not_supported}
  def handle_request("shh_getFilterChanges", _), do: {:error, :not_supported}
  def handle_request("shh_getMessages", _), do: {:error, :not_supported}

  defp decode_block_number(hex_block_number_or_tag) do
    case hex_block_number_or_tag do
      "pending" -> @sync.get_highest_block_number()
      "latest" -> @sync.get_highest_block_number()
      "earliest" -> @sync.get_starting_block_number()
      hex_number -> Exth.decode_unsigned_from_hex(hex_number)
    end
  end
end
