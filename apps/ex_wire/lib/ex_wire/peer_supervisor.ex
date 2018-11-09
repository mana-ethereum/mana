defmodule ExWire.PeerSupervisor do
  @moduledoc """
  The Peer Supervisor is responsible for maintaining a set of peer TCP
  connections. Currently this only manages outbound connections, and
  `TCP.InboundConnectionsSupervisor` manages inbound connections.
  """
  use DynamicSupervisor

  alias ExWire.Packet

  @name __MODULE__

  @spec start_link(list(String.t())) :: Supervisor.on_start()
  def start_link(nodes) do
    DynamicSupervisor.start_link(__MODULE__, nodes, name: @name)
  end

  @doc """
  Creates an outbound connection with peer.

  This function should be called when the Discovery portion of mana discovers new
  nodes.
  """
  @spec start_child(String.t()) :: DynamicSupervisor.on_start_child()
  def start_child(peer_enode_url) do
    {:ok, peer} = ExWire.Struct.Peer.from_uri(peer_enode_url)

    spec = {ExWire.P2P.Server, {:outbound, peer, [{:server, ExWire.Sync}]}}

    DynamicSupervisor.start_child(@name, spec)
  end

  @doc """
  Sends a packet to all active TCP connections. This is useful when we want to, for instance,
  ask for a `GetBlockBody` from all peers for a given block hash.
  """
  @spec send_packet(Packet.packet()) :: :ok | :unsent
  def send_packet(packet) do
    # Send to all of the Supervisor's children...
    # ... not the best.

    results =
      for {_id, child, _type, _modules} <- DynamicSupervisor.which_children(@name) do
        # Children which are being restarted by not have a child_pid at this time.
        if is_pid(child), do: ExWire.P2P.Server.send_packet(child, packet)
      end

    if Enum.member?(results, :ok), do: :ok, else: :unsent
  end

  @impl true
  def init(nodes) do
    {:ok, _} =
      Task.start_link(fn ->
        for node <- nodes, do: start_child(node)
      end)

    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
