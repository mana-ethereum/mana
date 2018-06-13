defmodule ExWire.Adapter.TCP.Server do
  @moduledoc """
  Server handling TCP data
  """

  use GenServer

  require Logger

  alias ExWire.Framing.Frame
  alias ExWire.{Handshake, Packet}

  @doc """
  Initialize by opening up a `gen_tcp` connection to given host and port.

  We'll also prepare and send out an authentication message immediately after connecting.
  """
  def init(state = %{is_outbound: true, peer: _peer}) do
    new_state =
      state
      |> generate_auth_credentials()
      |> establish_tcp_connection()

    send_auth_message(new_state.auth_data)

    {:ok, new_state}
  end

  def init(state = %{is_outbound: false}) do
    {:ok, state}
  end

  @doc """
  Sends auth message to a peer
  """
  def send_auth_message(auth_data) do
    GenServer.cast(self(), {:send_unframed_data, auth_data})
  end

  @doc """
  Sends acknowledgement message to peer
  """
  def send_ack_message(ack_data) do
    GenServer.cast(self(), {:send_unframed_data, ack_data})
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

  def handle_call({:subscribe, {:server, server} = server}, _from, state) do
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
  def handle_info({:tcp, _socket, data}, state = %{secrets: secrets}) when not is_nil(secrets) do
    {:noreply, handle_packet_data(data, state)}
  end

  def handle_info({:tcp, _socket, data}, state = %{is_outbound: true, auth_data: _auth_data}) do
    {:noreply, handle_acknowledgement_received(data, state)}
  end

  def handle_info({:tcp, _socket, data}, state = %{is_outbound: false}) do
    {:noreply, handle_auth_message_received(data, state)}
  end

  @doc """
  Function triggered when tcp closes the connection
  """
  def handle_info({:tcp_closed, _socket}, state) do
    message =
      if state.is_outbound do
        "[#{state.peer}] Peer closed connection"
      else
        "Peer closed connection"
      end

    Logger.warn("[Network] #{message}")

    Process.exit(self(), :normal)

    {:noreply, state}
  end

  @doc """
  If we receive a `send_unframed_data`, we'll send the data directly over the wire.
  """
  def handle_cast({:send_unframed_data, data}, state = %{socket: socket}) do
    message =
      if state.is_outbound do
        peer = state.peer
        "[#{peer}] Sending raw data message of length #{byte_size(data)} byte(s) to #{peer.host}"
      else
        "Sending raw data message of length #{byte_size(data)} byte(s)"
      end

    Logger.debug("[Network]" <> message)

    :ok = :gen_tcp.send(socket, data)

    {:noreply, state}
  end

  @doc """
  If we receive a `send` and we have secrets set, we'll send the message as a framed Eth packet.
  """
  def handle_cast(
        {:send, %{packet: {packet_mod, packet_type, packet_data}}},
        state = %{socket: socket, secrets: secrets}
      ) do
    message =
      if state.is_outbound do
        peer = state.peer
        "[#{peer}] Sending packet #{Atom.to_string(packet_mod)} to #{peer.host}"
      else
        "Sending packet #{Atom.to_string(packet_mod)}"
      end

    Logger.info("[Network]" <> message)

    {frame, updated_secrets} = Frame.frame(packet_type, packet_data, secrets)

    :ok = :gen_tcp.send(socket, frame)

    {:noreply, Map.merge(state, %{secrets: updated_secrets})}
  end

  @doc """
  Server function handling disconnecting from tcp connection. See TCP.disconnect/1
  """
  def handle_cast(:disconnect, state = %{socket: socket}) do
    :gen_tcp.shutdown(socket, :read_write)

    {:noreply, Map.delete(state, :socket)}
  end

  def handle_cast(:accept_tcp_messages, state = %{listen_socket: listen_socket}) do
    {:ok, socket} = :gen_tcp.accept(listen_socket)

    {:noreply, Map.put(state, :socket, socket)}
  end

  defp handle_acknowledgement_received(data, state) do
    %{
      peer: peer,
      auth_data: auth_data,
      my_ephemeral_key_pair:
        {_my_ephemeral_public_key, my_ephemeral_private_key} = _my_ephemeral_key_pair,
      my_nonce: my_nonce
    } = state

    case Handshake.try_handle_ack(data, auth_data, my_ephemeral_private_key, my_nonce) do
      {:ok, secrets, frame_rest} ->
        Logger.debug("[Network] [#{peer}] Got ack from #{peer.host}, deriving secrets")

        updated_state =
          Map.merge(state, %{
            secrets: secrets,
            auth_data: nil,
            my_ephemeral_key_pair: nil,
            my_nonce: nil
          })

        handle_packet_data(frame_rest, updated_state)

      {:invalid, reason} ->
        Logger.warn(
          "[Network] [#{peer}] Failed to get handshake message when expecting ack - #{reason}"
        )

        state
    end
  end

  defp handle_auth_message_received(data, state) do
    case Handshake.handle_auth(data) do
      {:ok, ack_data, secrets} ->
        Logger.debug("[Network] Received auth")

        send_ack_message(ack_data)

        Map.merge(state, %{secrets: secrets})

      {:invalid, reason} ->
        Logger.warn("[Network] Received unknown handshake message when expecting auth: #{reason}")

        state
    end
  end

  defp handle_packet_data(data, state) when byte_size(data) == 0, do: state

  defp handle_packet_data(data, state = %{peer: peer, secrets: secrets}) do
    total_data = Map.get(state, :queued_data, <<>>) <> data

    case Frame.unframe(total_data, secrets) do
      {:ok, packet_type, packet_data, frame_rest, updated_secrets} ->
        Logger.debug("[Network] [#{peer}] Got packet `#{inspect(packet_type)}` from #{peer.host}")

        get_packet(packet_type, packet_data) |> notify_subscribers(state)

        updated_state = Map.merge(state, %{secrets: updated_secrets, queued_data: <<>>})

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

  defp generate_auth_credentials(state = %{peer: peer}) do
    Logger.debug("[Network] Generating EIP8 Handshake for #{peer.host}")

    handshake =
      %Handshake{remote_pub: peer.remote_id}
      |> Handshake.initiate()

    Map.merge(state, %{
      auth_data: handshake.encoded_auth_msg,
      my_ephemeral_key_pair: handshake.random_key_pair,
      my_nonce: handshake.init_nonce
    })
  end

  defp establish_tcp_connection(state = %{peer: peer}) do
    {:ok, socket} = :gen_tcp.connect(peer.host |> String.to_charlist(), peer.port, [:binary])

    Logger.debug(
      "[Network] [#{peer}] Established outbound connection with #{peer.host}, sending auth."
    )

    Map.put(state, :socket, socket)
  end
end
