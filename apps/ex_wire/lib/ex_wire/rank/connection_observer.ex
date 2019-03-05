defmodule ExWire.Rank.ConnectionObserver do
  @moduledoc """
    Observing the inbound and outbound connections and gets notified if a connection gets dropped.
    It also stores all Peers (both inbound and outbound) for further analytics (measure and grade a peer based on how valuable that peer is to us).
  """
  use GenServer
  alias ExWire.Config
  alias ExWire.Kademlia
  alias ExWire.P2P.Connection
  alias ExWire.PeerSupervisor
  alias ExWire.Rank.PeerDetails
  alias ExWire.Struct.Peer

  require Logger

  @type t :: %__MODULE__{
          outbound_links: list(PeerDetails.t()),
          inbound_links: list(PeerDetails.t())
        }
  defstruct outbound_links: [], inbound_links: []

  @kademlia Application.get_env(:ex_wire, :kademlia_mock, Kademlia)

  def notify(:discovery_round) do
    GenServer.cast(__MODULE__, :kademlia_discovery_round)
  end

  @doc """
  Starts the observer process.
  """
  @spec start_link(:ok) :: GenServer.on_start()
  def start_link(:ok) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    Process.flag(:trap_exit, true)
    {:ok, %__MODULE__{}}
  end

  # getting exits from connections from us to them
  def handle_info(
        {:EXIT, _pid, {_, connection = %Connection{is_outbound: true}}},
        state
      ) do
    :ok = start_new_outbound_connections()
    {:noreply, enlist(connection, state)}
  end

  # getting exits from connections from them to us
  def handle_info(
        {:EXIT, _pid, {_, connection = %Connection{is_outbound: false}}},
        state
      ) do
    {:noreply, enlist(connection, state)}
  end

  # Kademlia server process notifies us of their discovery round.
  # We start new connections to peers from the discovery results.
  def handle_cast(:kademlia_discovery_round, state) do
    :ok = start_new_outbound_connections()

    {:noreply, state}
  end

  @spec start_new_outbound_connections() :: :ok
  defp start_new_outbound_connections() do
    this_round_nodes = @kademlia.get_peers()

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

  @spec enlist(Connection.t(), t) :: t
  defp enlist(
         connection = %Connection{is_outbound: true},
         state = %__MODULE__{outbound_links: outbound_links}
       ) do
    peer = connection.peer
    connection_initiated_at = connection.connection_initiated_at

    case Enum.find(outbound_links, fn p -> p === peer end) do
      nil ->
        # this is the first time that the connection dropped
        new_peer_details = %PeerDetails{
          peer: peer,
          connection_duration: Time.diff(Time.utc_now(), connection_initiated_at, :millisecond)
        }

        %{state | outbound_links: [new_peer_details | outbound_links]}

      _p ->
        # connection has dropped before or was restored from persistance
        state
    end
  end

  defp enlist(
         connection = %Connection{is_outbound: false},
         state = %__MODULE__{inbound_links: inbound_links}
       ) do
    peer = connection.peer
    connection_initiated_at = connection.connection_initiated_at

    case Enum.find(inbound_links, fn p -> p === peer end) do
      nil ->
        # this is the first time that the connection dropped
        new_peer_details = %PeerDetails{
          peer: peer,
          connection_duration: Time.diff(Time.utc_now(), connection_initiated_at)
        }

        %{state | inbound_links: [new_peer_details | inbound_links]}

      _p ->
        # connection has dropped before or was restored from persistance
        state
    end
  end
end
