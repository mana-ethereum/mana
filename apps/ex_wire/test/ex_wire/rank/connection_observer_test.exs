defmodule ExWire.Rank.ConnectionObserverTest do
  use ExUnit.Case, async: true

  alias ExWire.FakeKademlia
  alias ExWire.P2P.Connection
  alias ExWire.Rank.ConnectionObserver
  alias ExWire.Struct.Peer

  setup do
    pid_kademlia =
      start_supervised!({
        FakeKademlia,
        []
      })

    {:ok,
     %{
       fake_kademlia: pid_kademlia
     }}
  end

  test "if we are notified of discovery round messages", %{fake_kademlia: kademlia_pid} do
    pid = Process.whereis(ConnectionObserver)
    :ok = GenServer.call(kademlia_pid, :setup_get_peers_call)
    :erlang.trace(pid, true, [:receive])
    ConnectionObserver.notify(:discovery_round)
    assert_receive {:trace, ^pid, :receive, {_, :kademlia_discovery_round}}

    receive do
      :get_peers_call -> :ok
    end
  end

  test "if our process gets enlisted in the state", %{
    fake_kademlia: kademlia_pid
  } do
    pid = Process.whereis(ConnectionObserver)
    :ok = GenServer.call(kademlia_pid, :setup_get_peers_call)
    {:ok, client_pid} = __MODULE__.SimpleConnection.start(ConnectionObserver)
    __MODULE__.SimpleConnection.crash()

    {:links, links} = Process.info(pid, :links)
    true = Enum.member?(links, client_pid)
    # we'll pull the Observer state until we can find the crashed logged in it's internal state
    # the number of outbound crash logs should be exactly 1
    pull_state(pid, 100)
  end

  defp pull_state(_, 0), do: throw(:invalid_state_in_observer)

  defp pull_state(pid, n) do
    %{outbound_links: outbound_links} = :sys.get_state(pid, 5000)

    case Enum.count(outbound_links) do
      1 ->
        :ok

      0 ->
        :timer.sleep(10)
        pull_state(pid, n - 1)
    end
  end

  defmodule SimpleConnection do
    use GenServer

    def start(linker), do: GenServer.start(__MODULE__, [linker], name: __MODULE__)
    def crash(), do: GenServer.cast(__MODULE__, :crash_test)

    def init([connection_observer]) do
      Process.flag(:trap_exit, true)

      _ =
        connection_observer
        |> Process.whereis()
        |> Process.link()

      {:ok,
       %Connection{
         peer: %Peer{},
         is_outbound: true,
         subscribers: [],
         connection_initiated_at: Time.utc_now()
       }}
    end

    def handle_cast(:crash_test, state) do
      exit({:crash_test, state})
    end
  end
end
