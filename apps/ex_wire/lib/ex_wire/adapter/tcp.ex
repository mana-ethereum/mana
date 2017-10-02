defmodule ExWire.Adapter.TCP do
  @moduledoc """
  Starts a TCP server to handle incoming and outgoing RLPx connections.
  """
  use GenServer

  require Logger

  alias ExWire.Framing.Frame
  alias ExWire.Handshake
  alias ExWire.Packet

  @doc """
  Starts an outbound peer to peer connection.
  """
  def start_link(:outbound, host, port, remote_id) do
    GenServer.start_link(__MODULE__, %{is_outbound: true, host: host, port: port, remote_id: remote_id, active: false})
  end

  @doc """
  Initialize by opening up a `gen_tcp` connection to given host and port.

  We'll also prepare and send out an authentication message immediately after connecting.
  """
  def init(state=%{is_outbound: true, host: host, port: port, remote_id: remote_id}) do
    {:ok, socket} = :gen_tcp.connect(host |> String.to_charlist, port, [:binary])

    Logger.debug("[Network] Established outbound connection with #{host}, sending auth.")

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
      auth_data: encoded_auth_msg,
      my_ephemeral_key_pair: my_ephemeral_key_pair,
      my_nonce: my_nonce})}
  end

  @doc """
  Allows a client to new incoming packets.
  """
  def handle_call({:subscribe, {module, function, args}=mfa}, _from, state) do
    updated_state = Map.update(state, :subscribers, [mfa], fn subscribers -> [mfa | subscribers] end)

    {:reply, :ok, updated_state}
  end

  @doc """
  Handle info will handle when we have inbound communucation from a peer node.

  If we haven't yet completed our handshake, we'll await an auth or ack message
  as appropriate. That is, if we've established the connection and have sent an
  auth message, then we'll look for an ack. If we listened for a connection, we'll
  await an auth message.

  TODO: clients may send an auth before (or as) we do, and we should handle this case without error.
  """
  def handle_info(_info={:tcp, _socket, data}, state=%{is_outbound: true, remote_id: remote_id, host: host, auth_data: auth_data, my_ephemeral_key_pair: {_my_ephemeral_public_key, my_ephemeral_private_key}=my_ephemeral_key_pair, my_nonce: my_nonce}) do
    case Handshake.try_handle_ack(data, auth_data, my_ephemeral_private_key, my_nonce, host) do
      {:ok, secrets} ->

        Logger.debug("[Network] Got ack from #{host}, deriving secrets and sending HELLO")

        send_hello(self())

        {:noreply, Map.merge(state, %{
          secrets: secrets,
          auth_data: nil,
          my_ephemeral_key_pair: nil,
          my_nonce: nil,
          })}
      :invalid ->
        Logger.warn("[Network] Received unknown handshake message when expecting ack")
        Logger.debug("[Network] Message was: #{inspect data}")

        {:noreply, state}
    end
  end

  # TODO: How do we set remote id?
  def handle_info({:tcp, _socket, data}, state=%{is_outbound: false, remote_id: remote_id, host: host, my_ephemeral_key_pair: my_ephemeral_key_pair, my_nonce: my_nonce}) do
    case Handshake.try_handle_auth(data, my_ephemeral_key_pair, my_nonce, remote_id, host) do
      {:ok, ack_data, secrets} ->

        Logger.debug("[Network] Received auth from #{host}")

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
        Logger.warn("[Network] Received unknown handshake message when expecting auth")
        {:noreply, state}
    end
  end

  def handle_info(_info={:tcp, socket, data}, state=%{host: host, secrets: secrets}) do
    case Frame.unframe(data, secrets) do
      {:ok, packet_type, packet_data, frame_rest, updated_secrets} ->
        # TODO: Ignore non-HELLO messages unless state is active.

        # TODO: Maybe move into smaller functions for testing
        {packet, handle_result} = case Packet.get_packet_mod(packet_type) do
          {:ok, packet_mod} ->
            Logger.debug("[Network] Got packet #{Atom.to_string(packet_mod)} from #{host}")

            packet = packet_data
              |> packet_mod.deserialize()

            {packet, packet_mod.handle(packet)}
          :unknown_packet_type ->
            Logger.warn("[Network] Received unknown or unhandled packet type `#{packet_type}` from #{host}")

            {nil, :ok}
        end

        # Updates our given state and does any actions necessary
        handled_state = case handle_result do
          :ok -> state
          :activate -> Map.merge(state, %{active: true})
          :peer_disconnect ->
            :ok = :gen_tcp.shutdown(socket, :read_write)

            Map.merge(state, %{active: false})
          {:disconnect, reason} ->
            Logger.warn("[Network] Disconnecting to peer due to: #{Packet.Disconnect.get_reason_msg(reason)}")
            # TODO: Add a timeout and disconnect ourselves
            send_packet(self(), Packet.Disconnect.new(reason))

            state
          {:send, packet} ->
            send_packet(self(), packet)

            state
        end

        # Let's inform any subscribers
        if not is_nil(packet) do
          for {module, function, args} <- Map.get(state, :subscribers, []) do
            apply(module, function, [packet | args])
          end
        end

        updated_state = Map.merge(handled_state, %{secrets: updated_secrets})

        # If we have more packet data, we need to continue processing.
        if byte_size(frame_rest) == 0 do
          {:noreply, updated_state}
        else
          handle_info({:tcp, socket, frame_rest}, updated_state)
        end
      {:erorr, reason} ->
        Logger.error("[Network] Failed to read incoming packet from #{host} `#{reason}`)")

        {:noreply, state}
    end
  end

  def handle_info({:tcp_closed, _socket}, state) do
    Logger.warn("[Network] Peer closed connection.")

    {:noreply, Map.put(state, :active, false)}
  end

  @doc """
  If we receive a `send` before secrets are set, we'll send the data directly over the wire.
  """
  def handle_cast({:send, %{data: data}}, state = %{socket: socket, host: host}) do
    Logger.debug("[Network] Sending raw data message of length #{byte_size(data)} byte(s) to #{host}")

    :ok = :gen_tcp.send(socket, data)

    {:noreply, state}
  end

  @doc """
  If we receive a `send` and we have secrets set, we'll send the message as a framed Eth packet.
  """
  def handle_cast({:send, %{packet: {packet_mod, packet_type, packet_data}}}=data, state = %{host: host, active: false}) do
    Logger.info("[Network] Queueing packet #{Atom.to_string(packet_mod)} to #{host}")

    # TODO: Should we monitor this process, etc?
    pid = self()
    spawn fn ->
      :timer.sleep(500)
      GenServer.cast(pid, data)
    end

    {:noreply, state}
  end

  def handle_cast({:send, %{packet: {packet_mod, packet_type, packet_data}}}, state = %{socket: socket, secrets: secrets, host: host, active: true}) do
    Logger.info("[Network] Sending packet #{Atom.to_string(packet_mod)} to #{host}")

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
    {:ok, packet_mod} = Packet.get_packet_mod(packet_type)
    packet_data = packet_mod.serialize(packet)

    GenServer.cast(pid, {:send, %{packet: {packet_mod, packet_type, packet_data}}})

    :ok
  end

  @doc """
  Client function to send HELLO message after connecting.
  """
  def send_hello(pid) do
    send_packet(pid, %Packet.Hello{
      p2p_version: 0x04,
      client_id: "Exthereum/0.1",
      caps: [{"eth", 63}],
      listen_port: 30304,
      node_id: ExWire.public_key |> ExthCrypto.Key.der_to_raw
    })
  end

  @doc """
  Client function to subscribe to incoming packets.
  """
  def subscribe(pid, module, function, args) do
    :ok = GenServer.call(pid, {:subscribe, {module, function, args}})
  end

end