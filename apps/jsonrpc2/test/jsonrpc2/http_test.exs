defmodule JSONRPC2.HTTPTest do
  use ExUnit.Case, async: true
  alias JSONRPC2.Clients.HTTP
  alias JSONRPC2.Servers.WebSocketHTTP
  alias JSONRPC2.SpecHandlerTest

  setup_all do
    port = 56_752
    http = Application.get_env(:jsonrpc2, :http)

    http_configuration = WebSocketHTTP.new(http, :web)

    http_configuration =
      http_configuration
      |> Map.put(:enabled, true)
      |> Map.put(:port, port)

    ws = Application.get_env(:jsonrpc2, :ws)
    ws_configuration = WebSocketHTTP.new(ws, :ws)

    {:ok, _pid} =
      start_supervised(
        WebSocketHTTP.children(http_configuration, ws_configuration, SpecHandlerTest)
      )

    {:ok, %{port: port}}
  end

  test "call", %{port: port} do
    assert HTTP.call("http://localhost:#{port}/", "subtract", [2, 1]) == {:ok, 1}
  end

  test "notify", %{port: port} do
    assert HTTP.notify("http://localhost:#{port}/", "subtract", [2, 1]) == :ok
  end

  test "batch", %{port: port} do
    batch = [{"subtract", [2, 1]}, {"subtract", [2, 1], 0}, {"subtract", [2, 2], 1}]
    expected = [ok: {0, {:ok, 1}}, ok: {1, {:ok, 0}}]
    assert HTTP.batch("http://localhost:#{port}/", batch) == expected
  end

  test "call text/plain", %{port: port} do
    assert HTTP.call("http://localhost:#{port}/", "subtract", [2, 1], [
             {"content-type", "text/plain"}
           ]) == {:ok, 1}
  end

  test "notify text/plain", %{port: port} do
    assert HTTP.notify("http://localhost:#{port}/", "subtract", [2, 1], [
             {"content-type", "text/plain"}
           ]) == :ok
  end

  test "batch text/plain", %{port: port} do
    batch = [{"subtract", [2, 1]}, {"subtract", [2, 1], 0}, {"subtract", [2, 2], 1}]
    expected = [ok: {0, {:ok, 1}}, ok: {1, {:ok, 0}}]

    assert HTTP.batch("http://localhost:#{port}/", batch, [{"content-type", "text/plain"}]) ==
             expected
  end

  test "bad call", %{port: port} do
    assert {:error, {:http_request_failed, 404, _headers, {:ok, ""}}} =
             HTTP.call(
               "http://localhost:#{port}/",
               "subtract",
               [2, 1],
               [
                 {"content-type", "application/json"}
               ],
               :get
             )
  end
end
