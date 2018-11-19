defmodule JSONRPC2.ManaHandlerTest do
  use ExUnit.Case, async: true

  alias JSONRPC2.SpecHandler

  describe "examples from JSON-RPC 2.0 spec at http://www.jsonrpc.org/specification#examples" do
    test "rpc call with positional parameters" do
      _version = Application.get_env(:jsonrpc2, :mana_version)

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "web3_clientVersion", "params": [], "id": 1}),
        ~s({"jsonrpc": "2.0", "result": "0.0.1", "id": 1})
      )
    end

    test "web3sha 1" do
      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "web3_sha3", "params": ["0x00"], "id": 2}),
        ~s({"jsonrpc": "2.0", "result": "0xbc36789e7a1e281436464229828f817d6612f7b477d66591ff96a9e064bcc98a", "id": 2})
      )
    end

    test "web3sha 2" do
      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "web3_sha3", "params": ["0x68656c6c6f20776f726c6"], "id": 2}),
        ~s({"jsonrpc": "2.0", "error": {"code": -32602, "message": "Invalid params"}, "id": 2})
      )
    end
  end

  defp assert_rpc_reply(handler, call, expected_reply) do
    assert {:reply, reply} = handler.handle(call)
    assert Jason.decode(reply) == Jason.decode(expected_reply)
  end
end
