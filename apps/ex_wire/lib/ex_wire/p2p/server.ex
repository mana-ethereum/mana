defmodule ExWire.P2P.Server do
  @moduledoc """
  Server handling peer to peer communication.

  It starts a TCP server to handle incoming and outgoing RLPx, DevP2P, Eth Wire
  connection.

  Once this connection is up, it's possible to add a subscriber to the different
  packets that are sent over the connection. This is the primary way of handling
  packets.

  Note: incoming connections are not fully tested at this moment.
  Note: we do not currently store token to restart connections (this upsets some peers)
  """

  use GenServer

  require Logger

  alias ExWire.{P2P, TCP, Packet}
  alias ExWire.P2P.Inbound
  alias ExWire.P2P.Outbound
  alias ExWire.Struct.Peer

  @type subscription() :: {module(), atom(), list()} | {:server, pid()}

  @doc """
  Child spec definition to be used by a supervisor when wanting to supervise an
  inbound TCP connection.

  We spawn a temporary child process for each inbound connection.
  """
  @spec child_spec({:inbound, TCP.socket()} | {:outbound, Peer.t(), list(subscription())}) ::
          Supervisor.child_spec()
  def child_spec({:inbound, socket}) do
    %{
      id: Inbound,
      start: {__MODULE__, :start_link, [:inbound, socket]},
      restart: :temporary
    }
  end

  @doc """
  Child spec definition to be used by a supervisor when wanting to supervise an
  outbound TCP connection.

  We spawn a temporary child process for each outbound connection.
  """
  def child_spec({:outbound, peer, subscribers}) do
    %{
      id: Outbound,
      start: {__MODULE__, :start_link, [:outbound, peer, subscribers]},
      restart: :temporary
    }
  end

  @doc """
  Starts an outbound or inbound peer to peer connection.
  """
  @spec start_link(:outbound, Peer.t(), list(subscription())) :: GenServer.on_start()
  def start_link(:outbound, peer, subscribers) do
    GenServer.start_link(__MODULE__, %{
      is_outbound: true,
      peer: peer,
      subscribers: subscribers
    })
  end

  @spec start_link(:inbound, TCP.socket()) :: GenServer.on_start()
  def start_link(:inbound, socket) do
    GenServer.start_link(__MODULE__, %{
      is_outbound: false,
      socket: socket
    })
  end

  @doc """
  Client function for sending a packet over to a peer.
  """
  @spec send_packet(pid(), Packet.packet()) :: :ok
  def send_packet(pid, packet) do
    GenServer.cast(pid, {:send, %{packet: packet}})
  end

  @doc """
  Client function to subscribe to incoming packets.

  A subscription can be in one of two forms:

  1. Provide a `{:server, server_pid}`, and we will send a packet to that
  process with the contents `{:packet, packet, peer}` for each received packet.
  2. Provide a `{module, function, arguments}`, and we will apply that function
  with the provided arguments along with the packet.
  """
  @spec subscribe(pid(), subscription()) :: :ok
  def subscribe(pid, subscription) do
    GenServer.call(pid, {:subscribe, subscription})
  end

  @doc """
  Client function to disconnect from tcp connection
  """
  @spec disconnect(pid()) :: :ok
  def disconnect(pid) do
    GenServer.cast(pid, :disconnect)
  end

  @doc """
  Initialize by opening up a `gen_tcp` connection to given host and port.
  """
  @spec init(map()) :: {:ok, Connection.t()}
  def init(opts = %{is_outbound: true, peer: peer}) do
    {:ok, socket} = TCP.connect(peer.host, peer.port)

    _ =
      Logger.debug(fn ->
        "[Network] [#{peer}] Established outbound connection with #{peer.host}."
      end)

    state =
      socket
      |> P2P.new_outbound_connection(peer)
      |> Map.put(:subscribers, Map.get(opts, :subscribers, []))

    {:ok, state}
  end

  def init(opts = %{is_outbound: false, socket: socket}) do
    state =
      socket
      |> P2P.new_inbound_connection()
      |> Map.put(:subscribers, Map.get(opts, :subscribers, []))

    {:ok, state}
  end

  @doc """
  Allows a client to subscribe to incoming packets. Subscribers must be in the form
  of `{module, function, args}`, in which case we'll call `module.function(packet, ...args)`,
  or `{:server, server_pid}` for a GenServer, in which case we'll send a message
  `{:packet, packet, peer}`.
  """
  def handle_call({:subscribe, subscription}, _from, state) do
    {:ok, new_state} = handle_subscribe(subscription, state)

    {:reply, :ok, new_state}
  end

  @doc """
  Handle inbound communication from a peer node via tcp.
  """
  def handle_info({:tcp, _socket, data}, state) do
    {:ok, new_state} = handle_socket_message(data, state)

    {:noreply, new_state}
  end

  @doc """
  Function triggered when tcp closes the connection
  """
  def handle_info({:tcp_closed, _socket}, state) do
    {:ok, new_state} = handle_socket_close(state)

    {:noreply, new_state}
  end

  @doc """
  Server function for sending packets to a peer.
  """
  def handle_cast({:send, %{packet: packet}}, state) do
    {:ok, new_state} = handle_send(packet, state)

    {:noreply, new_state}
  end

  @doc """
  Server function handling disconnecting from tcp connection.
  """
  def handle_cast(:disconnect, state = %{socket: socket}) do
    {:ok, new_state} = handle_disconnection(socket, state)

    {:noreply, new_state}
  end

  @spec handle_subscribe(subscription(), Connection.t()) :: {:ok, Connection.t()}
  defp handle_subscribe({_module, _function, _args} = mfa, state) do
    new_state = Map.update(state, :subscribers, [mfa], fn subscribers -> [mfa | subscribers] end)

    {:ok, new_state}
  end

  defp handle_subscribe({:server, _server_pid} = server, state) do
    new_state =
      Map.update(state, :subscribers, [server], fn subscribers -> [server | subscribers] end)

    {:ok, new_state}
  end

  @spec handle_socket_message(binary(), Connection.t()) :: {:ok, Connection.t()}
  defp handle_socket_message(data, state) do
    new_state = P2P.handle_message(state, data)

    {:ok, new_state}
  end

  @spec handle_socket_close(Connection.t()) :: {:ok, Connection.t()}
  defp handle_socket_close(state) do
    peer = Map.get(state, :peer, :unknown)

    Logger.warn("[Network] [#{peer}] Peer closed connection")

    Process.exit(self(), :normal)

    {:ok, state}
  end

  @spec handle_send(Packet.packet(), Connection.t()) :: {:ok, Connection.t()}
  defp handle_send(packet, state) do
    new_state = P2P.send_packet(state, packet)

    {:ok, new_state}
  end

  @spec handle_disconnection(TCP.socket(), Connection.t()) :: {:ok, Connection.t()}
  defp handle_disconnection(socket, state) do
    :ok = TCP.shutdown(socket)
    new_state = Map.delete(state, :socket)

    {:ok, new_state}
  end
end
