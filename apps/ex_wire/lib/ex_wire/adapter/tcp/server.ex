defmodule ExWire.Adapter.TCP.Server do
  @moduledoc """
  Server handling TCP data
  """

  use GenServer

  require Logger

  alias ExWire.Framing.Frame
  alias ExWire.{Handshake, Packet, TCP}

  @doc """
  Initialize by opening up a `gen_tcp` connection to given host and port.

  We'll also prepare and send out an authentication message immediately after connecting.
  """
  def init(state = %{is_outbound: true, peer: _peer}) do
    new_state = establish_tcp_connection(state)

    send_auth_message()

    {:ok, new_state}
  end

  def init(state = %{is_outbound: false}) do
    {:ok, state}
  end

  @doc """
  Sends auth message to peer
  """
  def send_auth_message() do
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

  def handle_info({:tcp, _socket, data}, state = %{is_outbound: true, handshake: _handshake}) do
    {:noreply, handle_acknowledgement_received(data, state)}
  end

  def handle_info({:tcp, socket, data}, state = %{is_outbound: false}) do
    new_state = Map.put(state, :socket, socket)

    {:noreply, handle_auth_message_received(data, new_state)}
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
  Generates encoded auth message and sends it to peer. Stores credentials in
  state for decoded ack response.
  """
  def handle_cast(:send_auth_message, state = %{socket: socket, peer: peer}) do
    Logger.debug("[Network] Generating EIP8 Handshake for #{peer.host}")

    handshake =
      %Handshake{remote_pub: peer.remote_id}
      |> Handshake.initiate()

    new_state = Map.merge(state, %{handshake: handshake})

    Logger.debug("[Network] [#{peer}] Sending Handshake to #{peer.host}")
    send_unframed_data(new_state.auth_data, socket)

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

  defp handle_acknowledgement_received(data, state = %{peer: peer, handshake: handshake}) do
    case Handshake.handle_ack(data, handshake) do
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

  defp handle_auth_message_received(data, state = %{socket: socket}) do
    case Handshake.handle_auth(data) do
      {:ok, ack_data, secrets} ->
        Logger.debug("[Network] Received auth. Sending ack.")

        send_unframed_data(ack_data, socket)

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

  defp establish_tcp_connection(state = %{peer: peer}) do
    {:ok, socket} = TCP.connect(peer.host, peer.port)

    Logger.debug("[Network] [#{peer}] Established outbound connection with #{peer.host}.")

    Map.put(state, :socket, socket)
  end

  defp send_unframed_data(data, socket) do
    Logger.debug("[Network] Sending raw data message of length #{byte_size(data)} byte(s)")

    TCP.send_data(socket, data)
  end
end
