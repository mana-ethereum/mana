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

  alias ExWire.{TCP, P2P}

  @doc """
  Child spec definition to be used by a supervisor when wanting to supervise an
  inbound TCP connection.

  We spawn a temporary child process for each inbound connection.
  """
  def child_spec([:inbound, socket]) do
    %{
      id: ExWire.P2P.Inbound,
      start: {__MODULE__, :start_link, [{:inbound, socket}]},
      restart: :temporary
    }
  end

  @doc """
  Starts an outbound or inbound peer to peer connection.
  """
  def start_link(:outbound, peer, subscribers \\ []) do
    GenServer.start_link(__MODULE__, %{
      is_outbound: true,
      peer: peer,
      subscribers: subscribers
    })
  end

  def start_link({:inbound, socket}) do
    GenServer.start_link(__MODULE__, %{
      is_outbound: false,
      socket: socket
    })
  end

  @doc """
  Client function for sending a packet over to a peer.
  """
  @spec send_packet(pid(), struct()) :: :ok
  def send_packet(pid, packet) do
    GenServer.cast(pid, {:send, %{packet: packet}})
  end

  @doc """
  Client function to subscribe to incoming packets.

  A subscription can be in one of two forms:

  1. Provide a `{:server, server_pid}`, and we will send a packet to that
  process with the contents `{:packet, packet, peer}` for each received packet.
  2. Provde a `{module, function, arguments}`, and we will apply that function
  with the provided arguments along with the packet.
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

  @doc """
  Initialize by opening up a `gen_tcp` connection to given host and port.
  """
  def init(%{is_outbound: true, peer: peer}) do
    case TCP.connect(peer.host, peer.port) do
      {:ok, socket} ->
        Logger.debug(fn ->
          "[Network] [#{peer}] Established outbound connection with #{peer.host}."
        end)

        state = P2P.new_outbound_connection(socket, peer)

        {:ok, state}

      {:error, error} ->
        {:error, error}

        Logger.debug(fn ->
          "[Network] [#{peer}] failed to connect to #{peer.host}: #{error}."
        end)
    end
  end

  def init(%{is_outbound: false, socket: socket}) do
    state = P2P.new_inbound_connection(socket)

    {:ok, state}
  end

  @doc """
  Allows a client to subscribe to incoming packets. Subscribers must be in the form
  of `{module, function, args}`, in which case we'll call `module.function(packet, ...args)`,
  or `{:server, server_pid}` for a GenServer, in which case we'll send a message
  `{:packet, packet, peer}`.
  """
  def handle_call({:subscribe, {_module, _function, _args} = mfa}, _from, state) do
    updated_state =
      Map.update(state, :subscribers, [mfa], fn subscribers -> [mfa | subscribers] end)

    {:reply, :ok, updated_state}
  end

  def handle_call({:subscribe, {:server, _server_pid} = server}, _from, state) do
    updated_state =
      Map.update(state, :subscribers, [server], fn subscribers -> [server | subscribers] end)

    {:reply, :ok, updated_state}
  end

  @doc """
  Handle inbound communication from a peer node via tcp.
  """
  def handle_info({:tcp, _socket, data}, state) do
    new_state = P2P.handle_message(state, data)

    {:noreply, new_state}
  end

  @doc """
  Function triggered when tcp closes the connection
  """
  def handle_info({:tcp_closed, _socket}, state) do
    peer = Map.get(state, :peer, :unknown)

    Logger.warn("[Network] [#{peer}] Peer closed connection")

    Process.exit(self(), :normal)

    {:noreply, state}
  end

  @doc """
  Server function for sending packets to a peer.
  """
  def handle_cast({:send, %{packet: packet}}, state) do
    updated_state = P2P.send_packet(state, packet)

    {:noreply, updated_state}
  end

  @doc """
  Server function handling disconnecting from tcp connection.
  """
  def handle_cast(:disconnect, state = %{socket: socket}) do
    TCP.shutdown(socket)

    {:noreply, Map.delete(state, :socket)}
  end
end
