defmodule ExWire.ConnectionObserver do
  @moduledoc """
    Observing the inbound and outbound connections and gets notified if a connection gets dropped.
    It also stores all Peers (both inbound and outbound) for further use.
  """
  use GenServer
  alias ExWire.Config
  alias ExWire.Kademlia
  alias ExWire.P2P.Connection
  alias ExWire.PeerSupervisor
  alias ExWire.Struct.Peer
  require Logger

  @type t :: %__MODULE__{
          outbound_peers: MapSet.t(Peer.t()),
          inbound_peers: MapSet.t(Peer.t())
        }
  defstruct outbound_peers: MapSet.new(), inbound_peers: MapSet.new()

  def notify(:discovery_round) do
    GenServer.cast(__MODULE__, :kademlia_discovery_round)
  end

  @doc """
  Starts the observer process.
  """
  @spec start_link(:ok) :: GenServer.on_start()
  def start_link(:ok) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_) do
    Process.flag(:trap_exit, true)
    {:ok, %__MODULE__{}}
  end

  # getting exits of connections from us to them
  def handle_info(
        {:EXIT, _pid, {_, %Connection{is_outbound: true, peer: peer}}},
        state
      ) do
    :ok = start_new_outbound_connections()
    {:noreply, %{state | outbound_peers: MapSet.put(state.outbound_peers, peer)}}
  end

  # getting exits of connections from them to us
  def handle_info(
        {:EXIT, _pid, {_, %Connection{is_outbound: false, peer: peer}}},
        state
      ) do
    {:noreply, %{state | inbound_peers: MapSet.put(state.inbound_peers, peer)}}
  end

  # Kademlia server process notifies us of their discovery rounds.
  # We start new connections to peers from the discovery results.
  def handle_cast(:kademlia_discovery_round, state) do
    :ok = start_new_outbound_connections()

    {:noreply, state}
  end

  @spec start_new_outbound_connections() :: :ok
  defp start_new_outbound_connections() do
    this_round_nodes = Kademlia.get_peers()

    _ =
      if Config.perform_sync?() do
        for node <- this_round_nodes do
          node
          |> Peer.from_node()
          |> PeerSupervisor.new_peer(__MODULE__)
        end
      end

    :ok
  end
end
