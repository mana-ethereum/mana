defmodule JSONRPC2.TCPTest do
  use ExUnit.Case, async: true
  alias JSONRPC2.Clients.TCP, as: TCPClient
  alias JSONRPC2.Servers.TCP, as: TCPServer
  alias JSONRPC2.SpecHandlerTest

  setup_all do
    ipc = Application.get_env(:jsonrpc2, :ipc)
    path = ipc[:path]
    dirname = Path.dirname(path)
    :ok = File.mkdir_p(dirname)
    _ = File.rm(path)

    {:ok, pid} =
      Supervisor.start_link(
        [
          TCPServer.child_spec(SpecHandlerTest, 0, transport_opts: [{:ifaddr, {:local, path}}])
        ],
        strategy: :one_for_one
      )

    {:ok, client_pid} = TCPClient.start(path)

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
    assert TCPClient.call(client_pid, "subtract", [2, 1]) == {:ok, 1}

    assert TCPClient.call(client_pid, "subtract", [2, 1], true) == {:ok, 1}

    assert TCPClient.call(client_pid, "subtract", [2, 1], string_id: true) == {:ok, 1}

    assert TCPClient.call(client_pid, "subtract", [2, 1], timeout: 2_000) == {:ok, 1}
  end
end
