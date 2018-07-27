defmodule ExWire.Adapter.TCP.Server do
  @moduledoc """
  Server handling TCP data
  """

  use GenServer

  require Logger

  alias ExWire.Adapter.TCP, as: Client
  alias ExWire.Framing.Frame
  alias ExWire.{Handshake, Packet, TCP, DEVp2p}
  alias ExWire.Struct.Peer

  @doc """
  Initialize by opening up a `gen_tcp` connection to given host and port.

  We'll also prepare and send out an authentication message immediately after connecting.
  """
  def init(state = %{is_outbound: true, peer: peer}) do
    {:ok, socket} = TCP.connect(peer.host, peer.port)
    handshake = Handshake.new(peer.remote_id)

    Logger.debug(fn ->
      "[Network] [#{peer}] Established outbound connection with #{peer.host}."
    end)

    send_auth_message()

    {:ok, Map.merge(state, %{handshake: handshake, socket: socket})}
  end

  def init(state = %{is_outbound: false, socket: _socket}) do
    handshake = Handshake.new_response()

    {:ok, Map.put(state, :handshake, handshake)}
  end

  @doc """
  Sends auth message to peer
  """
  def send_auth_message do
    GenServer.cast(self(), :send_auth_message)
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
  Handle inbound communication from a peer node.

  If we have already performed the handshake, then we should have `secrets`
  defined. In that case, we simply need to handle packets as they come along.

  If we haven't yet completed the handshake, we'll await an auth or ack message
  as appropriate. That is, if we've established the connection and have sent an
  auth message, then we'll look for an ack. If we listened for a connection,
  we'll await an auth message.

  TODO: clients may send an auth before (or as) we do, and we should handle this case without error.
  """
  def handle_info({:tcp, _socket, data}, state = %{secrets: _secrets}) do
    {:noreply, handle_packet_data(data, state)}
  end

  def handle_info({:tcp, _socket, data}, state = %{handshake: handshake}) do
    new_state =
      case handshake do
        %Handshake{initiator: true} -> handle_acknowledgement_received(data, state)
        %Handshake{initiator: false} -> handle_auth_message_received(data, state)
      end

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
  Generates encoded auth message and sends it to peer. Stores credentials in
  state for decoded ack response.
  """
  def handle_cast(:send_auth_message, state = %{socket: socket, peer: peer}) do
    Logger.debug(fn -> "[Network] Generating EIP8 Handshake for #{peer.host}" end)

    handshake = Handshake.generate_auth(state.handshake)
    send_unframed_data(handshake.encoded_auth_msg, socket, peer)

    {:noreply, Map.merge(state, %{handshake: handshake})}
  end

  @doc """
  If we receive a `send` and we have secrets set, we'll send the message as a framed Eth packet.
  """
  def handle_cast({:send, %{packet: packet_data}}, state) do
    {packet_mod, packet_type, packet_data} = packet_data
    %{socket: socket, secrets: secrets, peer: peer} = state

    Logger.info("[Network] [#{peer}] Sending packet #{inspect(packet_mod)} to #{peer.host}")

    {frame, updated_secrets} = Frame.frame(packet_type, packet_data, secrets)

    TCP.send_data(socket, frame)

    {:noreply, Map.merge(state, %{secrets: updated_secrets})}
  end

  @doc """
  Server function handling disconnecting from tcp connection. See TCP.disconnect/1
  """
  def handle_cast(:disconnect, state = %{socket: socket}) do
    TCP.shutdown(socket)

    {:noreply, Map.delete(state, :socket)}
  end

  defp handle_acknowledgement_received(data, state = %{peer: peer}) do
    case Handshake.handle_ack(state.handshake, data) do
      {:ok, handshake, secrets} ->
        Logger.debug(fn -> "[Network] [#{peer}] Got ack from #{peer.host}, deriving secrets" end)

        session = initiate_dev_p2p_session()

        Map.merge(state, %{handshake: handshake, secrets: secrets, session: session})

      {:invalid, reason} ->
        Logger.warn(fn ->
          "[Network] [#{peer}] Failed to get handshake message when expecting ack - #{reason}"
        end)

        state
    end
  end

  defp handle_auth_message_received(data, state = %{socket: socket}) do
    case Handshake.handle_auth(state.handshake, data) do
      {:ok, handshake, secrets} ->
        peer = get_peer_info(handshake.auth_msg, socket)
        Logger.debug(fn -> "[Network] Received auth. Sending ack." end)

        send_unframed_data(handshake.encoded_ack_resp, socket, peer)
        session = initiate_dev_p2p_session()

        Map.merge(state, %{handshake: handshake, secrets: secrets, peer: peer, session: session})

      {:invalid, reason} ->
        Logger.warn(fn ->
          "[Network] Received unknown handshake message when expecting auth: #{reason}"
        end)

        state
    end
  end

  defp handle_packet_data(data, state) when byte_size(data) == 0, do: state

  defp handle_packet_data(data, state) do
    %{peer: peer, secrets: secrets, session: session} = state
    total_data = Map.get(state, :queued_data, <<>>) <> data

    case Frame.unframe(total_data, secrets) do
      {:ok, packet_type, packet_data, frame_rest, updated_secrets} ->
        Logger.debug(fn ->
          "[Network] [#{peer}] Got packet `#{inspect(packet_type)}` from #{peer.host}"
        end)

        updated_session =
          packet_type
          |> get_packet(packet_data)
          |> handle_packet(session, state)

        updated_state =
          Map.merge(state, %{
            secrets: updated_secrets,
            queued_data: <<>>,
            session: updated_session
          })

        handle_packet_data(frame_rest, updated_state)

      {:error, "Insufficent data"} ->
        Map.put(state, :queued_data, total_data)

      {:error, reason} ->
        Logger.error(
          "[Network] [#{peer}] Failed to read incoming packet from #{peer.host} `#{reason}`)"
        )

        state
    end
  end

  defp handle_packet(packet, session, state) do
    if DEVp2p.session_active?(session) do
      notify_subscribers(packet, state)
      session
    else
      attempt_session_activation(session, packet)
    end
  end

  defp attempt_session_activation(session, packet) do
    case DEVp2p.handle_message(session, packet) do
      {:ok, updated_session} -> updated_session
      {:error, :handshake_incomplete} -> session
    end
  end

  defp get_packet(packet_type, packet_data) do
    case Packet.get_packet_mod(packet_type) do
      {:ok, packet_mod} ->
        apply(packet_mod, :deserialize, [packet_data])

      :unknown_packet_type ->
        :unknown_packet_type
    end
  end

  defp notify_subscribers(:unknown_packet_type, _state), do: :noop

  defp notify_subscribers(packet, state) do
    for subscriber <- Map.get(state, :subscribers, []) do
      case subscriber do
        {module, function, args} -> apply(module, function, [packet | args])
        {:server, server} -> send(server, {:packet, packet, state.peer})
      end
    end
  end

  defp send_unframed_data(data, socket, peer) do
    Logger.debug(fn ->
      "[Network] [#{peer}] Sending raw data message of length #{byte_size(data)} byte(s) to #{
        peer.host
      }"
    end)

    TCP.send_data(socket, data)
  end

  defp initiate_dev_p2p_session do
    session = DEVp2p.init_session()
    hello = DEVp2p.build_hello()

    Client.send_packet(self(), hello)

    DEVp2p.hello_sent(session, hello)
  end

  defp get_peer_info(auth_msg, socket) do
    {host, port} = TCP.peer_info(socket)
    remote_id = Peer.hex_node_id(auth_msg.initiator_public_key)

    Peer.new(host, port, remote_id)
  end
end
