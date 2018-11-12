defmodule JSONRPC2.TCPTest do
  use ExUnit.Case, async: true
  alias JSONRPC2.Clients.TCP
  alias JSONRPC2.Servers.TCP, as: TCPServer
  alias JSONRPC2.SpecHandlerTest

  setup do
    port = :rand.uniform(65_535 - 1025) + 1025

    {:ok, pid} = TCPServer.start_listener(SpecHandlerTest, port, name: __MODULE__)

    :ok = TCP.start("localhost", port, __MODULE__)

    on_exit(fn ->
      ref = Process.monitor(pid)
      TCP.stop(__MODULE__)
      TCPServer.stop(__MODULE__)

      receive do
        {:DOWN, ^ref, :process, ^pid, :shutdown} -> :ok
      end
    end)
  end

  test "call" do
    assert TCP.call(__MODULE__, "subtract", [2, 1]) == {:ok, 1}

    assert TCP.call(__MODULE__, "subtract", [2, 1], true) == {:ok, 1}

    assert TCP.call(__MODULE__, "subtract", [2, 1], string_id: true) == {:ok, 1}

    assert TCP.call(__MODULE__, "subtract", [2, 1], timeout: 2_000) == {:ok, 1}
  end

  test "cast" do
    {:ok, request_id} = TCP.cast(__MODULE__, "subtract", [2, 1], timeout: 1_000)
    assert TCP.receive_response(request_id) == {:ok, 1}

    {:ok, request_id} = TCP.cast(__MODULE__, "subtract", [2, 1], true)
    assert TCP.receive_response(request_id) == {:ok, 1}

    {:ok, request_id} = TCP.cast(__MODULE__, "subtract", [2, 1], string_id: true, timeout: 2_000)

    assert TCP.receive_response(request_id) == {:ok, 1}
  end

  test "notify" do
    {:ok, _request_id} = TCP.notify(__MODULE__, "subtract", [2, 1])
  end
end
