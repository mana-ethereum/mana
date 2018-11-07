defmodule ExWire.P2P do
  require Logger

  alias ExWire.Framing.Frame
  alias ExWire.{DEVp2p, Handshake, Packet, TCP}
  alias ExWire.Struct.Peer

  defmodule Connection do
    @type t :: %Connection{
            peer: ExWire.Struct.Peer.t(),
            socket: port(),
            handshake: ExWire.Handshake.t(),
            secrets: ExWire.Framing.Secrets.t() | nil,
            queued_data: binary(),
            session: ExWire.DEVp2p.Session.t(),
            subscribers: [any()]
          }

    defstruct peer: nil,
              socket: nil,
              handshake: nil,
              secrets: nil,
              queued_data: <<>>,
              session: nil,
              subscribers: []
  end

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

  TODO: clients may send an auth before (or as) we do, and we should handle this case without error.
  """
  def handle_message(conn = %{secrets: %ExWire.Framing.Secrets{}}, data) do
    handle_packet_data(data, conn)
  end

  def handle_message(conn = %{handshake: %Handshake{}}, data) do
    conn
    |> handle_encrypted_handshake(data)
    |> prepare_devp2p_session()
  end

  defp prepare_devp2p_session(conn = %Connection{secrets: %ExWire.Framing.Secrets{}}) do
    session = initiate_dev_p2p_session()
    send_packet(conn, session.hello_sent)
    %{conn | session: session}
  end

  defp prepare_devp2p_session(conn), do: conn

  defp handle_encrypted_handshake(conn = %Connection{handshake: handshake}, data) do
    case handshake do
      %Handshake{initiator: true} ->
        handle_acknowledgement_received(data, conn)

      %Handshake{initiator: false} ->
        handle_auth_message_received(data, conn)
    end
  end

  defp handle_packet_data(data, conn) when byte_size(data) == 0, do: conn

  defp handle_packet_data(data, conn) do
    %Connection{peer: peer, secrets: secrets, session: session} = conn
    total_data = conn.queued_data <> data

    case Frame.unframe(total_data, secrets) do
      {:ok, packet_type, packet_data, frame_rest, updated_secrets} ->
        _ =
          Logger.debug(fn ->
            "[Network] [#{peer}] Got packet `#{inspect(packet_type)}` from #{peer.host}"
          end)

        updated_session =
          packet_type
          |> get_packet(packet_data)
          |> handle_packet(session, conn)

        updated_conn = %{
          conn
          | secrets: updated_secrets,
            queued_data: <<>>,
            session: updated_session
        }

        handle_packet_data(frame_rest, updated_conn)

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

  defp handle_packet(packet, session, conn) do
    if DEVp2p.session_active?(session) do
      do_handle_packet(packet, conn)
      session
    else
      attempt_session_activation(session, packet)
    end
  end

  defp do_handle_packet(packet = %Packet.Status{}, conn) do
    return_packet =
      case Packet.Status.handle(packet) do
        :ok ->
          Packet.Status.new(packet)

        {:disconnect, reason} ->
          Packet.Disconnect.new(reason)
      end

    send_packet(conn, return_packet)
  end

  defp do_handle_packet(_packet = %Packet.Disconnect{}, conn) do
    TCP.shutdown(conn.socket)
  end

  defp do_handle_packet(packet = %Packet.Ping{}, conn) do
    {:send, pong} = Packet.Ping.handle(packet)
    send_packet(conn, pong)
  end

  defp do_handle_packet(packet, conn) do
    notify_subscribers(packet, conn)
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

  defp notify_subscribers(:unknown_packet_type, _conn), do: :noop

  defp notify_subscribers(packet, conn) do
    for subscriber <- Map.get(conn, :subscribers, []) do
      case subscriber do
        {module, function, args} -> apply(module, function, [packet | args])
        {:server, server} -> send(server, {:packet, packet, conn.peer})
      end
    end
  end

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
  def send_packet(conn, packet) do
    %{socket: socket, secrets: secrets, peer: peer} = conn

    {:ok, packet_type} = Packet.get_packet_type(packet)
    {:ok, packet_mod} = Packet.get_packet_mod(packet_type)

    :ok = Logger.info("[Network] [#{peer}] Sending packet #{inspect(packet_mod)} to #{peer.host}")

    packet_data = apply(packet_mod, :serialize, [packet])

    {frame, updated_secrets} = Frame.frame(packet_type, packet_data, secrets)

    TCP.send_data(socket, frame)

    Map.merge(conn, %{secrets: updated_secrets})
  end

  defp send_unframed_data(data, socket, peer) do
    _ =
      Logger.debug(fn ->
        "[Network] [#{peer}] Sending raw data message of length #{byte_size(data)} byte(s) to #{
          peer.host
        }"
      end)

    TCP.send_data(socket, data)
  end

  defp initiate_dev_p2p_session() do
    session = DEVp2p.init_session()
    hello = DEVp2p.build_hello()

    DEVp2p.hello_sent(session, hello)
  end

  defp get_peer_info(auth_msg, socket) do
    {host, port} = TCP.peer_info(socket)
    remote_id = Peer.hex_node_id(auth_msg.initiator_public_key)

    Peer.new(host, port, remote_id)
  end
end
