defmodule JSONRPC2.SpecHandler do
  use JSONRPC2.Server.Handler

  alias Blockchain.Block
  alias Blockchain.Blocktree
  alias ExthCrypto.Hash.Keccak
  alias ExWire.PeerSupervisor
  alias ExWire.Sync
  # web3 Methods

  def handle_request("web3_clientVersion", _), do: Application.get_env(:jsonrpc2, :mana_version)
  def handle_request("web3_sha3", [param = "0x" <> _]), do: Keccak.kec(param)

  # net Methods
  def handle_request("net_version", _), do: Application.get_env(:ex_wire, :network_id)
  def handle_request("net_listening", _), do: Application.get_env(:ex_wire, :discovery)
  def handle_request("net_peerCount", _), do: PeerSupervisor.connected_peer_count()

  # eth Methods
  def handle_request("eth_protocolVersion", _), do: {:error, :not_supported}

  def handle_request("eth_syncing", _) do
    sync_state = get_last_sync_state()

    current_block = get_last_sync_block(sync_state)

    %{
      currentBlock: current_block,
      startingBlock: sync_state.starting_block_number,
      highestBlock: sync_state.highest_block_number
    }
  end

  def handle_request("eth_coinbase", _), do: {:error, :not_supported}
  def handle_request("eth_mining", _), do: {:error, :not_supported}
  def handle_request("eth_hashrate", _), do: {:error, :not_supported}
  def handle_request("eth_gasPrice", _), do: {:error, :not_supported}
  def handle_request("eth_accounts", _), do: {:error, :not_supported}

  def handle_request("eth_blockNumber", _) do
    block = get_last_sync_block(get_last_sync_state())
    block.header.number
  end

  def handle_request("eth_getBalance", _), do: {:error, :not_supported}
  def handle_request("eth_getStorageAt", _), do: {:error, :not_supported}
  def handle_request("eth_getTransactionCount", _), do: {:error, :not_supported}
  def handle_request("eth_getBlockTransactionCountByHash", _), do: {:error, :not_supported}
  def handle_request("eth_getBlockTransactionCountByNumber", _), do: {:error, :not_supported}
  def handle_request("eth_getUncleCountByBlockHash", _), do: {:error, :not_supported}
  def handle_request("eth_getUncleCountByBlockNumber", _), do: {:error, :not_supported}
  def handle_request("eth_getCode", _), do: {:error, :not_supported}
  def handle_request("eth_sign", _), do: {:error, :not_supported}
  def handle_request("eth_sendTransaction", _), do: {:error, :not_supported}
  def handle_request("eth_sendRawTransaction", _), do: {:error, :not_supported}
  def handle_request("eth_call", _), do: {:error, :not_supported}
  def handle_request("eth_estimateGas", _), do: {:error, :not_supported}
  def handle_request("eth_getBlockByHash", _), do: {:error, :not_supported}
  def handle_request("eth_getBlockByNumber", _), do: {:error, :not_supported}
  def handle_request("eth_getTransactionByHash", _), do: {:error, :not_supported}
  def handle_request("eth_getTransactionByBlockHashAndIndex", _), do: {:error, :not_supported}
  def handle_request("eth_getTransactionByBlockNumberAndIndex", _), do: {:error, :not_supported}
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

  @spec get_last_sync_state() :: Sync.state()
  defp get_last_sync_state(), do: Sync.get_state()

  @spec get_last_sync_block(Sync.state()) :: Block.t()
  defp get_last_sync_block(state) do
    {:ok, {block, _caching_trie}} =
      Blocktree.get_best_block(state.block_tree, state.chain, state.trie)

    block
  end
end
