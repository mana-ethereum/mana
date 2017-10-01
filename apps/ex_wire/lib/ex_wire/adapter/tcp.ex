defmodule ExWire.Adapter.TCP do
  @moduledoc """
  Starts a TCP server to handle incoming and outgoing RLPx connections.
  """
  use GenServer

  require Logger

  alias ExthCrypto.Hash.Keccak
  alias ExWire.Framing.Frame
  alias ExWire.Handshake
  alias ExWire.Packet

  @doc """
  Starts an outbound peer to peer connection.
  """
  def start_link(:outbound, host, port, my_ephemeral_key_pair, my_nonce, remote_id) do
    GenServer.start_link(__MODULE__, %{is_outbound: true, host: host, port: port, my_ephemeral_key_pair: my_ephemeral_key_pair, my_nonce: my_nonce, remote_id: remote_id})
  end

  @doc """
  Initialize by opening up a `gen_tcp` connection to given host and port.

  We'll also prepare and send out an authentication message immediately after connecting.
  """
  def init(state=%{is_outbound: true, host: host, port: port, remote_id: remote_id}) do
    {:ok, socket} = :gen_tcp.connect(host |> String.to_charlist, port, [:binary])

    Logger.debug("Established outbound connection with #{host}")

    # TODO: Move into simpler function
    {my_auth_msg, my_ephemeral_key_pair, my_nonce} = ExWire.Handshake.build_auth_msg(
      ExWire.public_key,
      ExWire.private_key,
      remote_id
    )

    {:ok, encoded_auth_msg} = my_auth_msg
      |> ExWire.Handshake.Struct.AuthMsgV4.serialize()
      |> ExWire.Handshake.EIP8.wrap_eip_8(remote_id, host, my_ephemeral_key_pair)

    # Send auth message
    GenServer.cast(self(), {:send, %{data: encoded_auth_msg}})

    {:ok, Map.merge(state, %{
      socket: socket,
      auth_data: encoded_auth_msg})}
  end

  @doc """
  Handle info will handle when we have inbound communucation from a peer node.

  If we haven't yet completed our handshake, we'll await an auth or ack message
  as appropriate. That is, if we've established the connection and have sent an
  auth message, then we'll look for an ack. If we listened for a connection, we'll
  await an auth message.

  TODO: clients may send an auth before (or as) we do, and we should handle this case without error.
  """
  def handle_info(info={:tcp, _socket, data}, state=%{is_outbound: true, host: host, port: port, auth_data: auth_data, my_ephemeral_key_pair: {my_ephemeral_public_key, my_ephemeral_private_key}, my_nonce: my_nonce}) do
    case Handshake.try_handle_ack(data, auth_data, my_ephemeral_public_key, my_nonce, host) do
      {:ok, secrets} ->

        Logger.debug("Received ack from #{host}")

        send_hello(self())

        {:noreply, Map.merge(state, %{
          secrets: secrets,
          auth_data: nil,
          my_ephemeral_key_pair: nil,
          my_nonce: nil,
          })}
      :invalid ->
        Logger.warn("Received unknown handshake message when expecting ack")
        {:noreply, state}
    end
  end

  # TODO: How do we set remote id?
  def handle_info(info={:tcp, _socket, data}, state=%{is_outbound: false, remote_id: remote_id, host: host, port: port, my_ephemeral_key_pair: {my_ephemeral_public_key, my_ephemeral_private_key}=my_ephemeral_key_pair, my_nonce: my_nonce}) do
    case Handshake.try_handle_auth(data, my_ephemeral_key_pair, my_nonce, remote_id, host) do
      {:ok, ack_data, secrets} ->

        Logger.debug("Received auth from #{host}")

        # Send ack back to sender
        GenServer.cast(self(), {:send, %{data: ack_data}})

        send_hello(self())

        # But we're set on our secrets
        {:noreply, Map.merge(state, %{
          secrets: secrets,
          auth_data: nil,
          my_ephemeral_key_pair: nil,
          my_nonce: nil,
          })}
      :invalid ->
        Logger.warn("Received unknown handshake message when expecting auth")
        {:noreply, state}
    end
  end

  def handle_info(info={:tcp, socket, data}, state=%{is_outbound: is_outbound, host: host, port: port, secrets: secrets}) do
    case Frame.unframe(data, secrets) do
      {:ok, packet_type, packet_data, frame_rest, updated_secrets} ->

        # TODO: Ignore non-HELLO messages unless state is active.

        # TODO: Maybe move into smaller functions for testing
        handle_result = case ExWire.Packet.get_packet_mod(packet_type) do
          {:ok, packet_mod} ->
            Logger.debug("Got packet #{Atom.to_string(packet_mod)} from #{host}")

            packet_data
              |> packet_mod.deserialize()
              |> packet_mod.handle()
          :unknown_packet_type ->
            Logger.warn("Received unknown or unhandled packet type `#{packet_type}` from #{host}")

            :ok
        end

        # Updates our given state and does any actions necessary
        handled_state = case handle_result do
          :ok -> state
          :activate -> Map.merge(state, %{active: true})
          :peer_disconnect ->
            :gen_tcp.disconnect(socket)

            Map.merge(state, %{active: false})
          {:disconnect, reason} ->
            # TODO: Add a timeout and disconnect ourselves
            send_packet(self(), Packet.Disconnect.new(reason))

            state
          {:send, packet} ->
            send_packet(self(), packet)

            state
        end

        updated_state = Map.merge(handled_state, %{secrets: updated_secrets})

        # If we have more packet data, we need to continue processing.
        if byte_size(frame_rest) == 0 do
          {:noreply, updated_state}
        else
          handle_info({:tcp, socket, frame_rest}, updated_state)
        end
      {:erorr, reason} ->
        Logger.error("Failed to read incoming packet from #{host}")

        {:noreply, state}
    end

    # case packet_type do
    #   0x00 ->
    #     IO.inspect(["Got HELLO", packet_data], limit: :infinity)
    #   0x01 ->
    #     IO.inspect(["Got DISCONNECT", packet_data])
    #   0x02 ->
    #     IO.inspect(["Got PING, not responding PONG"])

    #     send_packet(self(), 0x03, [])
    #   0x03 ->
    #     IO.inspect(["Got PONG"])
    #   user_packet when user_packet >= 0x10 ->
    #     status_eth_id = ExWire.Packet.Status.eth_id
    #     blocks_eth_id = ExWire.Packet.Blocks.eth_id

    #     case user_packet - 0x10 do
    #       ^status_eth_id ->
    #         her_status = ExWire.Packet.Status.deserialize(packet_data)
    #         IO.inspect(["Got STATUS", her_status], limit: :infinity)

    #         my_status = %ExWire.Packet.Status{
    #           protocol_version: 63,
    #           network_id: 3,
    #           total_difficulty: 0,
    #           best_hash: <<>>,
    #           genesis_hash: <<>>
    #         }

    #         send_packet(self(), 0x10 + ExWire.Packet.Status.eth_id, my_status |> ExWire.Packet.Status.serialize)

    #         get_blocks = %ExWire.Packet.GetBlocks{
    #           hashes: [her_status.genesis_hash]
    #         } |> IO.inspect

    #         send_packet(self(), 0x10 + ExWire.Packet.GetBlocks.eth_id, get_blocks |> ExWire.Packet.GetBlocks.serialize)
    #       ^blocks_eth_id ->
    #         IO.inspect(["Got packet data", packet_data], limit: :infinity)
    #         blocks = ExWire.Packet.Blocks.deserialize(packet_data)

    #         IO.inspect(["Got blocks", blocks], limit: :infinity)
    #       eth_id ->
    #         IO.inspect(["Unknown user packet", eth_id])
    #     end
    # end
  end

  @doc """
  If we receive a `send` before secrets are set, we'll send the data directly over the wire.
  """
  def handle_cast({:send, %{data: data}}=info, state = %{socket: socket, host: host}) do
    Logger.debug("Sending raw data message of length #{byte_size(data)} byte(s) to #{host}")

    :ok = :gen_tcp.send(socket, data)

    {:noreply, state}
  end

  @doc """
  If we receive a `send` and we have secrets set, we'll send the message as a framed Eth packet.
  """
  def handle_cast({:send, %{packet: {packet_mod, packet_type, packet_data}}}=info, state = %{socket: socket, secrets: secrets, host: host}) do
    Logger.info("Sending packet #{Atom.to_string(packet_mod)} to #{host}")

    {frame, updated_secrets} = Frame.frame(packet_type, packet_data, secrets)

    :ok = :gen_tcp.send(socket, frame)

    {:noreply, Map.merge(state, %{secrets: updated_secrets})}
  end

  @doc """
  Client function for sending a packet over to a peer.
  """
  @spec send_packet(pid(), struct()) :: :ok
  def send_packet(pid, packet) do
    {:ok, packet_type} = Packet.get_packet_type(packet)
    packet_mod = Packet.get_packet_mod(packet_type)
    packet_data = packet_mod.serialize(packet)

    GenServer.cast(self(), {:send, %{packet: {packet_mod, packet_type, packet_data}}})

    :ok
  end

  @doc """
  Client function to send HELLO message after connecting.
  """
  def send_hello(pid) do
    send_packet(pid, %Packet.Hello{
      p2p_version: 0x04,
      client_id: "Exthereum/0.1",
      caps: [["eth", 63]],
      listen_port: 30304,
      node_id: ExWire.public_key |> ExthCrypto.Key.der_to_raw
    })
  end

end