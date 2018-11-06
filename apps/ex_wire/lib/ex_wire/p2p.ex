defmodule ExWire.P2P do
  require Logger

  alias ExWire.Framing.Frame
  alias ExWire.{DEVp2p, Handshake, Packet, TCP}
  alias ExWire.DEVp2p.Session
  alias ExWire.P2P.Connection
  alias ExWire.Struct.Peer

  @doc """
  Function to create an outbound connection with a peer. It expects a `socket`
  and a `peer` to be provided. This function starts the encrypted handshake with
  the `peer`.
  """
  @spec new_outbound_connection(port(), Peer.t()) :: Connection.t()
  def new_outbound_connection(socket, peer) do
    handshake =
      peer.remote_id
      |> Handshake.new()
      |> Handshake.generate_auth()

    send_unframed_data(handshake.encoded_auth_msg, socket, peer)

    %Connection{socket: socket, peer: peer, handshake: handshake}
  end

  @doc """
  Function to create an inbound connection with a peer. It expects a `socket`
  but not a `peer` at this moment. The full peer information will be obtained from
  the socket and the auth message when it arrives.
  """
  @spec new_inbound_connection(port()) :: Connection.t()
  def new_inbound_connection(socket) do
    handshake = Handshake.new_response()

    %Connection{socket: socket, handshake: handshake}
  end

  @doc """
  Handle inbound messages from a peer node.

  First we must ensure we perform an encrypted handshake. If such a handshake
  has already occurred, then we should have derived the `secrets`. In that case,
  we take the message to be a `packet`.

  If we haven't yet completed the encrypted handshake, we'll await for an auth
  or an ack message as appropriate. If this is an outbound connection, then we
  assume we have sent the auth message, and we're looking for an ack response.
  If this is an inbound connection, we assume the peer will send an auth message
  first, so we await for that message.

  TODO: clients may send an auth before (or as) we do, and we should handle this
        case without error.
  """
  def handle_message(conn = %{secrets: %ExWire.Framing.Secrets{}}, data) do
    handle_packet_data(data, conn)
  end

  def handle_message(conn = %{handshake: %Handshake{}}, data) do
    conn
    |> handle_encrypted_handshake(data)
    |> prepare_devp2p_session()
  end

  @spec handle_encrypted_handshake(Connection.t(), binary()) :: Connection.t()
  defp handle_encrypted_handshake(conn = %Connection{handshake: handshake}, data) do
    case handshake do
      %Handshake{initiator: true} ->
        handle_acknowledgement_received(data, conn)

      %Handshake{initiator: false} ->
        handle_auth_message_received(data, conn)
    end
  end

  @spec prepare_devp2p_session(Connection.t()) :: Connection.t()
  defp prepare_devp2p_session(conn = %Connection{secrets: %ExWire.Framing.Secrets{}}) do
    session = initiate_dev_p2p_session()

    conn
    |> Map.put(:session, session)
    |> send_packet(session.hello_sent)
  end

  defp prepare_devp2p_session(conn), do: conn

  @spec handle_packet_data(binary(), Connection.t()) :: Connection.t()
  defp handle_packet_data(data, conn) when byte_size(data) == 0, do: conn

  defp handle_packet_data(data, conn) do
    %Connection{peer: peer, secrets: secrets} = conn

    total_data = conn.queued_data <> data

    case Frame.unframe(total_data, secrets) do
      {:ok, packet_type, packet_data, frame_rest, updated_secrets} ->
        conn_after_unframe = %{
          conn
          | secrets: updated_secrets,
            queued_data: <<>>
        }

        # TODO: What do we do about unknown packets?
        conn_after_handle =
          case get_packet(packet_type, packet_data) do
            {:ok, packet_mod, packet} ->
              :ok =
                Logger.debug(fn ->
                  "[Network] [#{peer}] Got packet `#{inspect(packet_mod)}` from #{peer.host}"
                end)

              notify_subscribers(packet, conn_after_unframe)
              new_conn = handle_packet(packet_mod, packet, conn_after_unframe)

              new_conn

            :unknown_packet_type ->
              Logger.error(fn ->
                "[Network] [#{peer}] Got unknown packet `#{packet_type}` from #{peer.host}"
              end)

              conn_after_unframe
          end

        # TOOD: How does this work exactly? Is this for multiple frames?
        handle_packet_data(frame_rest, conn_after_handle)

      {:error, "Insufficent data"} ->
        %{conn | queued_data: total_data}

      {:error, reason} ->
        _ =
          Logger.error(
            "[Network] [#{peer}] Failed to read incoming packet from #{peer.host} `#{reason}`)"
          )

        conn
    end
  end

  @spec handle_packet(module(), Packet.t(), Connection.t()) :: Connection.t()
  defp handle_packet(packet_mod, packet, conn) do
    packet_handle_response = packet_mod.handle(packet)

    if not DEVp2p.session_active?(conn.session) && packet_handle_response != :activate do
      Logger.error(fn -> "Expected message prior to activation, got: #{inspect(packet)}" end)
    end

    case packet_handle_response do
      :ok ->
        conn

      :activate ->
        new_session =
          if DEVp2p.session_active?(conn.session) do
            Logger.error(fn ->
              "Attempting to re-activate active session, session=#{inspect(conn.session)}, packet=#{
                inspect(packet)
              }"
            end)

            conn.session
          else
            attempt_session_activation(conn.session, packet)
          end

        %{conn | session: new_session}

      :peer_disconnect ->
        TCP.shutdown(conn.socket)

        conn

      {:disconnect, reason} ->
        disconnect_packet = Packet.Disconnect.new(reason)

        send_packet(conn, disconnect_packet)

      {:send, return_packet} ->
        send_packet(conn, return_packet)
    end
  end

  @spec attempt_session_activation(Session.t(), Packet.t()) :: Session.t()
  defp attempt_session_activation(session, packet) do
    case DEVp2p.handle_message(session, packet) do
      {:ok, updated_session} ->
        updated_session

      {:error, :handshake_incomplete} ->
        Logger.warn(fn -> "Ignoring message #{inspect(packet)} due to handshake incomplete." end)

        session
    end
  end

  @spec get_packet(integer(), binary()) :: {:ok, module(), Packet.t()} | :unknown_packet_type
  defp get_packet(packet_type, packet_data) do
    with {:ok, packet_mod} <- Packet.get_packet_mod(packet_type) do
      {:ok, packet_mod, apply(packet_mod, :deserialize, [packet_data])}
    end
  end

  @spec notify_subscribers(Packet.t(), Connection.t()) :: list()
  defp notify_subscribers(packet, conn) do
    for subscriber <- Map.get(conn, :subscribers, []) do
      case subscriber do
        {module, function, args} -> apply(module, function, [packet | args])
        {:server, server} -> send(server, {:packet, packet, conn.peer})
      end
    end
  end

  @spec handle_acknowledgement_received(binary(), Connection.t()) :: Connection.t()
  defp handle_acknowledgement_received(data, conn = %{peer: peer}) do
    case Handshake.handle_ack(conn.handshake, data) do
      {:ok, handshake, secrets} ->
        _ =
          Logger.debug(fn -> "[Network] [#{peer}] Got ack from #{peer.host}, deriving secrets" end)

        Map.merge(conn, %{handshake: handshake, secrets: secrets})

      {:invalid, reason} ->
        :ok =
          Logger.warn(
            "[Network] [#{peer}] Failed to get handshake message when expecting ack - #{reason}"
          )

        conn
    end
  end

  @spec handle_auth_message_received(binary(), Connection.t()) :: Connection.t()
  defp handle_auth_message_received(data, conn = %{socket: socket}) do
    case Handshake.handle_auth(conn.handshake, data) do
      {:ok, handshake, secrets} ->
        peer = get_peer_info(handshake.auth_msg, socket)

        _ = Logger.debug("[Network] Received auth. Sending ack.")
        send_unframed_data(handshake.encoded_ack_resp, socket, peer)

        Map.merge(conn, %{handshake: handshake, secrets: secrets, peer: peer})

      {:invalid, reason} ->
        :ok =
          Logger.warn(
            "[Network] Received unknown handshake message when expecting auth: #{reason}"
          )

        conn
    end
  end

  @doc """
  Function for sending a packet over to a peer.
  """
  @spec send_packet(Connection.t(), Packet.t()) :: Connection.t()
  def send_packet(conn, packet) do
    %{socket: socket, secrets: secrets, peer: peer} = conn

    {:ok, packet_type} = Packet.get_packet_type(packet)
    {:ok, packet_mod} = Packet.get_packet_mod(packet_type)

    :ok =
      Logger.info(
        "[Network] [#{peer}] Sending packet #{inspect(packet_mod)} to #{peer.host} (##{
          conn.sent_message_count + 1
        })"
      )

    packet_data = apply(packet_mod, :serialize, [packet])

    {frame, updated_secrets} = Frame.frame(packet_type, packet_data, secrets)

    TCP.send_data(socket, frame)

    Map.merge(conn, %{
      secrets: updated_secrets,
      sent_message_count: conn.sent_message_count + 1
    })
  end

  @spec send_unframed_data(binary(), TCP.socket(), Peer.t()) :: :ok | {:error, any()}
  defp send_unframed_data(data, socket, peer) do
    _ =
      Logger.debug(fn ->
        "[Network] [#{peer}] Sending raw data message of length #{byte_size(data)} byte(s) to #{
          peer.host
        }"
      end)

    TCP.send_data(socket, data)
  end

  @spec initiate_dev_p2p_session() :: Session.t()
  defp initiate_dev_p2p_session() do
    session = DEVp2p.init_session()
    hello = DEVp2p.build_hello()

    DEVp2p.hello_sent(session, hello)
  end

  @spec get_peer_info(ExWire.Handshake.Struct.AuthMsgV4.t(), TCP.socket()) :: Peer.t()
  defp get_peer_info(auth_msg, socket) do
    {host, port} = TCP.peer_info(socket)
    remote_id = Peer.hex_node_id(auth_msg.initiator_public_key)

    Peer.new(host, port, remote_id)
  end
end
