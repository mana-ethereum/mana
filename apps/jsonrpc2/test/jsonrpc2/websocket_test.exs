defmodule JSONRPC2.WebSocketTest do
  use ExUnit.Case, async: false
  alias JSONRPC2.Clients.WebSocketStack
  alias JSONRPC2.Servers.WebSocketHTTP

  alias JSONRPC2.SpecHandlerTest

  setup_all do
    port = 56_753

    ws = Application.get_env(:jsonrpc2, :ws)

    ws_configuration = WebSocketHTTP.new(ws, :ws)

    ws_configuration =
      ws_configuration
      |> Map.put(:enabled, true)
      |> Map.put(:port, port)

    http = Application.get_env(:jsonrpc2, :http)
    http_configuration = WebSocketHTTP.new(http, :web)

    {:ok, pid} =
      start_supervised(
        WebSocketHTTP.children(http_configuration, ws_configuration, SpecHandlerTest)
      )

    {:ok, client_pid} =
      GenServer.start_link(WebSocketStack, %{external_request_id: 0, port: port})

    on_exit(fn ->
      ref = Process.monitor(pid)
      _ = Process.exit(pid, :kill)

      receive do
        {:DOWN, ^ref, :process, _, _} -> :ok
      end
    end)

    {:ok, %{client_pid: client_pid}}
  end

  test "call", %{client_pid: client_pid} do
    result = WebSocketStack.call(client_pid, "subtract", [2, 1])
    assert result == {:ok, 1}
  end

  test "batch", %{client_pid: client_pid} do
    batch = [{"subtract", [2, 1]}, {"subtract", [2, 1], 0}, {"subtract", [2, 2], 1}]
    expected = [ok: {0, {:ok, 1}}, ok: {1, {:ok, 0}}]
    assert WebSocketStack.batch(client_pid, batch) == expected
  end
end
