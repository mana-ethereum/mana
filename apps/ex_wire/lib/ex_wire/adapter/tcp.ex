defmodule ExWire.Adapter.TCP do
  @moduledoc """
  Starts a TCP server to handle incoming and outgoing RLPx, DevP2P, Eth Wire connection.

  Once this connection is up, it's possible to add a subscriber to the different packets
  that are sent over the connection. This is the primary way of handling packets.

  Note: incoming connections are not fully tested at this moment.
  Note: we do not currently store token to restart connections (this upsets some peers)
  """

  alias ExWire.Packet

  @doc """
  Starts an outbound or inbound peer to peer connection.
  """
  def start_link(:outbound, peer, subscribers \\ []) do
    GenServer.start_link(ExWire.Adapter.TCP.Server, %{
      is_outbound: true,
      peer: peer,
      subscribers: subscribers
    })
  end

  def start_link(:inbound) do
    GenServer.start_link(ExWire.Adapter.TCP.Server, %{
      is_outbound: false,
      tcp_port: ExWire.Config.listen_port()
    })
  end

  @doc """
  Client function for sending a packet over to a peer.
  """
  @spec send_packet(pid(), struct()) :: :ok
  def send_packet(pid, packet) do
    {:ok, packet_type} = Packet.get_packet_type(packet)
    {:ok, packet_mod} = Packet.get_packet_mod(packet_type)
    packet_data = packet_mod.serialize(packet)

    GenServer.cast(pid, {:send, %{packet: {packet_mod, packet_type, packet_data}}})
  end

  @doc """
  Client function to subscribe to incoming packets.

  A subscription should be in the form of `{:server, server_pid}`, and we will
  send a packet to that server with contents `{:packet, packet, peer}` for
  each received packet.
  """
  @spec subscribe(pid(), {module(), atom(), list()} | {:server, pid()}) :: :ok
  def subscribe(pid, subscription) do
    GenServer.call(pid, {:subscribe, subscription})
  end

  @doc """
  Client function to disconnect from tcp connection
  """
  def disconnect(pid) do
    GenServer.cast(pid, :disconnect)
  end
end
