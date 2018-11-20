defmodule JSONRPC2.ManaHandlerTest do
  use ExUnit.Case, async: true

  alias JSONRPC2.BridgeSyncMock
  alias JSONRPC2.SpecHandler

  describe "is web3_clientVersion method behaving correctly when" do
    test "called without params" do
      version = Application.get_env(:jsonrpc2, :mana_version)

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "web3_clientVersion", "params": [], "id": 1}),
        ~s({"jsonrpc": "2.0", "result": "#{version}", "id": 1})
      )
    end
  end

  describe "is web3sha method behaving correctly when" do
    test "empty address" do
      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "web3_sha3", "params": ["0x00"], "id": 2}),
        ~s({"jsonrpc": "2.0", "result": "0xbc36789e7a1e281436464229828f817d6612f7b477d66591ff96a9e064bcc98a", "id": 2})
      )
    end

    test "params that are not base16" do
      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "web3_sha3", "params": ["0x68656c6c6f20776f726c6"], "id": 2}),
        ~s({"jsonrpc": "2.0", "error": {"code": -32602, "message": "Invalid params"}, "id": 2})
      )
    end

    test "params that are base16" do
      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "web3_sha3", "params": ["0x68656c6c6f20776f726c64"], "id": 5}),
        ~s({"jsonrpc": "2.0", "result": "0x47173285a8d7341e5e972fc677286384f802f8ef42a5ec5f03bbfa254cb01fad", "id": 5})
      )
    end
  end

  describe "is net_version method behaving correctly when" do
    test "called without params" do
      network_id = Application.get_env(:ex_wire, :network_id)

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "net_version", "params": [], "id": 1}),
        ~s({"jsonrpc": "2.0", "result": "#{network_id}", "id": 1})
      )
    end
  end

  describe "is net_listening method behaving correctly when" do
    test "called without params" do
      discovery = Application.get_env(:ex_wire, :discovery)

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "net_listening", "params": [], "id": 1}),
        ~s({"jsonrpc": "2.0", "result": #{discovery}, "id": 1})
      )
    end
  end

  describe "is net_peerCount method behaving correctly when" do
    setup do
      {:ok, pid} = BridgeSyncMock.start_link(%{})
      {:ok, %{pid: pid}}
    end

    test "called without params for 0 peers", %{pid: _pid} do
      connected_peer_count = 0
      :ok = BridgeSyncMock.set_connected_peer_count(connected_peer_count)

      expected_result_count = "0x0"

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "net_peerCount", "params": [], "id": 74}),
        ~s({"jsonrpc": "2.0", "result": "#{expected_result_count}", "id": 74})
      )
    end

    test "called without params for 2 peers", %{pid: _pid} do
      connected_peer_count = 2
      :ok = BridgeSyncMock.set_connected_peer_count(connected_peer_count)

      expected_result_count = "0x2"

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "net_peerCount", "params": [], "id": 74}),
        ~s({"jsonrpc": "2.0", "result": "#{expected_result_count}", "id": 74})
      )
    end
  end

  describe "is eth_syncing method behaving correctly when" do
    setup do
      {:ok, pid} = BridgeSyncMock.start_link(%{})
      {:ok, %{pid: pid}}
    end

    test "all parameters are 0", %{pid: _pid} do
      :ok = BridgeSyncMock.set_last_sync_block_stats({0, 0, 0})

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_syncing", "params": [], "id": 74}),
        ~s({"jsonrpc": "2.0", "result": {"currentBlock":"0x0","startingBlock":"0x0","highestBlock":"0x0"}, "id": 74})
      )
    end

    test "all parameters are above 0", %{pid: _pid} do
      :ok = BridgeSyncMock.set_last_sync_block_stats({900, 902, 1108})

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_syncing", "params": [], "id": 71}),
        ~s({"jsonrpc": "2.0", "result": {"currentBlock":"0x384","startingBlock":"0x386", "highestBlock":"0x454"}, "id": 71})
      )
    end
  end

  defp assert_rpc_reply(handler, call, expected_reply) do
    assert {:reply, reply} = handler.handle(call)
    assert Jason.decode(reply) == Jason.decode(expected_reply)
  end
end
