defmodule ExWire.ConnectionObserverTest do
  use ExUnit.Case, async: true
  alias ExWire.ConnectionObserver
  alias ExWire.FakeKademlia

  test "if we are notified of discovery round messages" do
    pid = Process.whereis(ConnectionObserver)
    {:ok, kademlia_pid} = FakeKademlia.start_link()
    :ok = GenServer.call(kademlia_pid, :setup_get_peers_call)
    :erlang.trace(pid, true, [:receive])
    ConnectionObserver.notify(:discovery_round)
    assert_receive {:trace, ^pid, :receive, {_, :kademlia_discovery_round}}

    receive do
      :get_peers_call -> :ok
    end
  end
end
