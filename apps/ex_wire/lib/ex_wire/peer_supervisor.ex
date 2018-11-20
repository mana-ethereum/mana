defmodule ExWire.PeerSupervisor do
  @moduledoc """
  The Peer Supervisor is responsible for maintaining a set of peer TCP
  connections. Currently this only manages outbound connections, and
  `TCP.InboundConnectionsSupervisor` manages inbound connections.
  """
  use DynamicSupervisor

  require Logger

  alias ExWire.P2P.Server
  alias ExWire.Packet
  alias ExWire.Struct.Peer

  @type node_selector :: :all | :random | :last

  @name __MODULE__

  @max_peers 10

  @spec start_link(list(String.t())) :: Supervisor.on_start()
  def start_link(nodes) do
    DynamicSupervisor.start_link(__MODULE__, nodes, name: @name)
  end

  @doc """
  Initiates an outbound connection with peer.

  This function should be called when we want connect to a new peer, this may
  come from start-up or via discovery (e.g. a find neighbors response).
  """
  @spec new_peer(Peer.t()) :: any()
  def new_peer(peer) do
    peer_count = connected_peer_count()

    if peer_count < @max_peers do
      :ok =
        Logger.debug(fn ->
          "[PeerSup] Connecting to peer #{peer} (#{peer_count} of #{@max_peers} peers)"
        end)

      spec = {Server, {:outbound, peer, [{:server, ExWire.Sync}]}}

      {:ok, _pid} = DynamicSupervisor.start_child(@name, spec)
    else
      :ok =
        Logger.debug(fn -> "[PeerSup] Not connecting due to max peers (#{@max_peers}) reached" end)
    end
  end

  @doc """
  Sends a packet to all active TCP connections. This is useful when we want to, for instance,
  ask for a `GetBlockBody` from all peers for a given block hash.
  """
  @spec send_packet(pid, Packet.packet(), node_selector()) :: :ok
  def send_packet(parent, packet, node_selector) do
    children = find_children(node_selector)
    do_send_packet(parent, packet, children)
  end

  @spec send_packet(Packet.packet(), node_selector()) :: :ok
  def send_packet(packet, node_selector) do
    children = find_children(node_selector)
    do_send_packet(packet, children)
  end

  defp do_send_packet(_packet, []) do
    :no_children
  end

  defp do_send_packet(packet, children) do
    for child <- children do
      Exth.trace(fn ->
        "[PeerSup] Sending #{to_string(packet.__struct__)} packet to peer #{
          inspect(Server.get_peer(child).ident)
        }"
      end)

      Server.send_packet(child, packet)
    end

    :ok
  end

  defp do_send_packet(parent, _packet, []), do: GenServer.cast(parent, :no_children)

  defp do_send_packet(_parent, packet, children) do
    for child <- children do
      Exth.trace(fn ->
        "[PeerSup] Sending #{to_string(packet.__struct__)} packet to peer #{
          inspect(Server.get_peer(child).ident)
        }"
      end)

      Server.send_packet(child, packet)
    end

    :ok
  end

  @spec find_children(node_selector()) :: list(pid())
  defp find_children(node_selector) do
    children =
      for {_id, child, _type, _modules} <- do_find_children(node_selector) do
        child
      end

    # Children which are being restarted by not have a child_pid at this time.
    Enum.filter(children, &is_pid/1)
  end

  @spec do_find_children(node_selector()) :: list(any())
  defp do_find_children(:all) do
    DynamicSupervisor.which_children(@name)
  end

  defp do_find_children(:last) do
    @name
    |> DynamicSupervisor.which_children()
    |> List.last()
    |> List.wrap()
  end

  defp do_find_children(:random) do
    @name
    |> DynamicSupervisor.which_children()
    |> Enum.random()
    |> List.wrap()
  end

  @spec connected_peer_count() :: non_neg_integer()
  def connected_peer_count() do
    @name
    |> DynamicSupervisor.which_children()
    |> Enum.count()
  end

  @impl true
  def init(peer_enode_urls) do
    _ =
      Task.start_link(fn ->
        for peer_enode_url <- peer_enode_urls do
          {:ok, peer} = ExWire.Struct.Peer.from_uri(peer_enode_url)

          new_peer(peer)
        end
      end)

    {:ok, _} = DynamicSupervisor.init(strategy: :one_for_one)
  end
end
