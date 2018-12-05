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

  alias ExWire.P2P.Connection
  alias ExWire.P2P.Manager
  alias ExWire.Packet
  alias ExWire.Struct.Peer
  alias ExWire.TCP

  @type state :: Connection.t()

  @type subscription() :: {module(), atom(), list()} | {:server, Process.dest()}

  @doc """
  Child spec definition to be used by a supervisor when wanting to supervise an
  inbound TCP connection.

  We spawn a temporary child process for each inbound connection.
  """
  @spec child_spec({:inbound, TCP.socket()} | {:outbound, Peer.t(), list(subscription())}) ::
          Supervisor.child_spec()
  def child_spec({:inbound, socket}) do
    %{
      id: ExWire.P2P.Inbound,
      start: {__MODULE__, :start_link, [:inbound, socket]},
      restart: :temporary
    }
  end

  @doc """
  Child spec definition to be used by a supervisor when wanting to supervise an
  outbound TCP connection.

  We spawn a temporary child process for each outbound connection.
  """
  def child_spec({:outbound, peer, subscribers, connection_observer}) do
    %{
      id: ExWire.P2P.Outbound,
      start: {__MODULE__, :start_link, [:outbound, peer, subscribers, connection_observer]},
      restart: :temporary
    }
  end

  @doc """
  Starts an outbound or inbound peer to peer connection.
  """
  @spec start_link(:outbound, Peer.t(), list(subscription()), module()) :: GenServer.on_start()
  def start_link(:outbound, peer, subscribers, connection_observer) do
    GenServer.start_link(__MODULE__, %{
      is_outbound: true,
      peer: peer,
      subscribers: subscribers,
      connection_observer: connection_observer
    })
  end

  @spec start_link(:inbound, TCP.socket(), module()) :: GenServer.on_start()
  def start_link(:inbound, socket, connection_observer) do
    GenServer.start_link(__MODULE__, %{
      is_outbound: false,
      socket: socket,
      connection_observer: connection_observer
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
  Client function to get peer associated with this gen server
  """
  @spec get_peer(pid()) :: Peer.t()
  def get_peer(pid) do
    GenServer.call(pid, :get_peer, :infinity)
  end

  @doc """
  Initialize by opening up a `gen_tcp` connection to given host and port.
  """
  @spec init(map()) :: {:ok, state()}
  def init(opts = %{is_outbound: true, peer: peer, connection_observer: connection_observer}) do
    Process.send_after(self(), :connect, 0)
    true = link(connection_observer)

    state = %Connection{
      peer: peer,
      is_outbound: true,
      subscribers: Map.get(opts, :subscribers, []),
      timer: Time.utc_now()
    }

    {:ok, state}
  end

  def init(opts = %{is_outbound: false, connection_observer: connection_observer}) do
    state0 = struct(Connection, opts)

    state =
      state0
      |> Manager.new_inbound_connection()
      |> Map.put(:subscribers, Map.get(opts, :subscribers, []))
      |> Map.put(:timer, Time.utc_now())

    true = link(connection_observer)
    {:ok, state}
  end

  def handle_call(:get_peer, _from, state = %{peer: peer}) do
    {:reply, peer, state}
  end

  def handle_call({:subscribe, subscription}, _from, state) do
    {:ok, new_state} = handle_subscribe(subscription, state)

    {:reply, :ok, new_state}
  end

  def handle_info(:connect, state = %{peer: peer}) do
    {:ok, socket0} = TCP.connect(peer.host, peer.port)

    :ok =
      Logger.debug(fn ->
        "[Network] [#{peer}] Established outbound connection with #{peer.host_name}."
      end)

    state0 = Manager.new_outbound_connection(%{state | socket: socket0})

    {:noreply, state0}
  end

  @doc """
  Handle inbound communication from a peer node via tcp.
  """
  def handle_info({:tcp, _socket, data}, state) do
    {:ok, new_conn} = handle_socket_message(data, state)

    {:noreply, new_conn}
  end

  @doc """
  Function triggered when tcp closes the connection
  """
  def handle_info({:tcp_closed, _socket}, state) do
    :ok = handle_socket_close(state)

    {:stop, :normal, state}
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

  # links should get reason and state
  def terminate(reason, state) do
    exit({reason, state})
  end

  # Allows a client to subscribe to incoming packets. Subscribers must be in the form
  # of `{module, function, args}`, in which case we'll call `module.function(packet, ...args)`,
  # or `{:server, server_pid}` for a GenServer, in which case we'll send a message
  # `{:packet, packet, peer}`.
  @spec handle_subscribe(subscription(), state()) :: {:ok, state()}
  defp handle_subscribe(mfa = {_module, _function, _args}, state) do
    new_state = Map.update(state, :subscribers, [mfa], fn subscribers -> [mfa | subscribers] end)

    {:ok, new_state}
  end

  defp handle_subscribe(server = {:server, _server_pid}, state) do
    new_state =
      Map.update(state, :subscribers, [server], fn subscribers -> [server | subscribers] end)

    {:ok, new_state}
  end

  @spec handle_socket_message(binary(), state()) :: {:ok, state()}
  defp handle_socket_message(data, state) do
    new_state = Manager.handle_message(state, data)

    {:ok, new_state}
  end

  @spec handle_socket_close(state()) :: :ok
  defp handle_socket_close(state) do
    peer = Map.get(state, :peer, :unknown)
    is_outbound = Map.get(state, :is_outbound)

    Logger.warn(fn -> "[Network] [#{peer} is_outbound: #{is_outbound}] Peer closed connection" end)
  end

  @spec handle_send(Packet.packet(), state()) :: {:ok, state()}
  defp handle_send(packet, state) do
    new_state = Manager.send_packet(state, packet)

    {:ok, new_state}
  end

  @spec handle_disconnection(TCP.socket(), state()) :: {:ok, state()}
  defp handle_disconnection(socket, state) do
    :ok = TCP.shutdown(socket)
    new_state = Map.delete(state, :socket)

    {:ok, new_state}
  end

  @spec link(module()) :: true
  defp link(connection_observer),
    do:
      connection_observer
      |> Process.whereis()
      |> Process.link()
end
