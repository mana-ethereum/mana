defmodule ExWire.Adapter.TCP do
  @moduledoc """
  Starts a TCP server to handle incoming and outgoing RLPx, DevP2P, Eth Wire connection.

  Once this connection is up, it's possible to add a subscriber to the different packets
  that are sent over the connection. This is the primary way of handling packets.

  Note: incoming connections are not fully tested at this moment.
  Note: we do not currently store token to restart connections (this upsets some peers)
  """
  use GenServer

  require Logger

  alias ExWire.Framing.Frame
  alias ExWire.Handshake
  alias ExWire.Packet

  @doc """
  Starts an outbound peer to peer connection.
  """
  def start_link(:outbound, peer, subscribers \\ []) do
    GenServer.start_link(__MODULE__, %{
      is_outbound: true,
      peer: peer,
      active: false,
      subscribers: subscribers
    })
  end

  @doc """
  Initialize by opening up a `gen_tcp` connection to given host and port.

  We'll also prepare and send out an authentication message immediately after connecting.
  """
  def init(state = %{is_outbound: true, peer: peer}) do
    {:ok, socket} = :gen_tcp.connect(peer.host |> String.to_charlist(), peer.port, [:binary])

    Logger.debug(
      "[Network] [#{peer}] Established outbound connection with #{peer.host}, sending auth."
    )

    {my_auth_msg, my_ephemeral_key_pair, my_nonce} =
      ExWire.Handshake.build_auth_msg(
        ExWire.Config.public_key(),
        ExWire.Config.private_key(),
        peer.remote_id
      )

    {:ok, encoded_auth_msg} =
      my_auth_msg
      |> ExWire.Handshake.Struct.AuthMsgV4.serialize()
      |> ExWire.Handshake.EIP8.wrap_eip_8(peer.remote_id, peer.host, my_ephemeral_key_pair)

    # Send auth message
    GenServer.cast(self(), {:send, %{data: encoded_auth_msg}})

    {:ok,
     Map.merge(state, %{
       socket: socket,
       auth_data: encoded_auth_msg,
       my_ephemeral_key_pair: my_ephemeral_key_pair,
       my_nonce: my_nonce
     })}
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
  Handle info will handle when we have inbound communucation from a peer node.

  If we haven't yet completed our handshake, we'll await an auth or ack message
  as appropriate. That is, if we've established the connection and have sent an
  auth message, then we'll look for an ack. If we listened for a connection, we'll
  await an auth message.

  TODO: clients may send an auth before (or as) we do, and we should handle this case without error.
  """
  def handle_info(
        _info = {:tcp, socket, data},
        state = %{
          is_outbound: true,
          peer: peer,
          auth_data: auth_data,
          my_ephemeral_key_pair:
            {_my_ephemeral_public_key, my_ephemeral_private_key} = _my_ephemeral_key_pair,
          my_nonce: my_nonce
        }
      ) do
    case Handshake.try_handle_ack(data, auth_data, my_ephemeral_private_key, my_nonce, peer.host) do
      {:ok, secrets, frame_rest} ->
        Logger.debug(
          "[Network] [#{peer}] Got ack from #{peer.host}, deriving secrets and sending HELLO"
        )

        send_hello(self())

        updated_state =
          Map.merge(state, %{
            secrets: secrets,
            auth_data: nil,
            my_ephemeral_key_pair: nil,
            my_nonce: nil
          })

        if byte_size(frame_rest) == 0 do
          {:noreply, updated_state}
        else
          handle_info({:tcp, socket, frame_rest}, updated_state)
        end

      {:invalid, reason} ->
        Logger.warn(
          "[Network] [#{peer}] Failed to get handshake message when expecting ack - #{reason}"
        )

        {:noreply, state}
    end
  end

  # TODO: How do we set remote id?
  def handle_info(
        {:tcp, _socket, data},
        state = %{
          is_outbound: false,
          peer: peer,
          my_ephemeral_key_pair: my_ephemeral_key_pair,
          my_nonce: my_nonce
        }
      ) do
    case Handshake.try_handle_auth(
           data,
           my_ephemeral_key_pair,
           my_nonce,
           peer.remote_id,
           peer.host
         ) do
      {:ok, ack_data, secrets} ->
        Logger.debug("[Network] [#{peer}] Received auth from #{peer.host}")

        # Send ack back to sender
        GenServer.cast(self(), {:send, %{data: ack_data}})

        send_hello(self())

        # But we're set on our secrets
        {:noreply,
         Map.merge(state, %{
           secrets: secrets,
           auth_data: nil,
           my_ephemeral_key_pair: nil,
           my_nonce: nil
         })}

      {:invalid, reason} ->
        Logger.warn(
          "[Network] [#{peer}] Received unknown handshake message when expecting auth - #{reason}"
        )

        {:noreply, state}
    end
  end

  def handle_info(_info = {:tcp, socket, data}, state = %{peer: peer, secrets: secrets}) do
    total_data = Map.get(state, :queued_data, <<>>) <> data

    case Frame.unframe(total_data, secrets) do
      {:ok, packet_type, packet_data, frame_rest, updated_secrets} ->
        # TODO: Ignore non-HELLO messages unless state is active.

        # TODO: Maybe move into smaller functions for testing
        {packet, handle_result} =
          case Packet.get_packet_mod(packet_type) do
            {:ok, packet_mod} ->
              Logger.debug(
                "[Network] [#{peer}] Got packet #{Atom.to_string(packet_mod)} from #{peer.host}"
              )

              packet =
                packet_data
                |> packet_mod.deserialize()

              {packet, packet_mod.handle(packet)}

            :unknown_packet_type ->
              Logger.warn(
                "[Network] [#{peer}] Received unknown or unhandled packet type `#{packet_type}` from #{
                  peer.host
                }"
              )

              {nil, :ok}
          end

        # Updates our given state and does any actions necessary
        handled_state =
          case handle_result do
            :ok ->
              state

            :activate ->
              Map.merge(state, %{active: true})

            :peer_disconnect ->
              # Doesn't matter if this succeeds or not
              :gen_tcp.shutdown(socket, :read_write)

              Map.merge(state, %{active: false})

            {:disconnect, reason} ->
              Logger.warn(
                "[Network] [#{peer}] Disconnecting to peer due to: #{
                  Packet.Disconnect.get_reason_msg(reason)
                }"
              )

              # TODO: Add a timeout and disconnect ourselves
              send_packet(self(), Packet.Disconnect.new(reason))

              state

            {:send, packet} ->
              send_packet(self(), packet)

              state
          end

        # Let's inform any subscribers
        if not is_nil(packet) do
          for subscriber <- Map.get(state, :subscribers, []) do
            case subscriber do
              {module, function, args} -> apply(module, function, [packet | args])
              {:server, server} -> send(server, {:packet, packet, peer})
            end
          end
        end

        updated_state = Map.merge(handled_state, %{secrets: updated_secrets, queued_data: <<>>})

        # If we have more packet data, we need to continue processing.
        if byte_size(frame_rest) == 0 do
          {:noreply, updated_state}
        else
          handle_info({:tcp, socket, frame_rest}, updated_state)
        end

      {:error, "Insufficent data"} ->
        {:noreply, Map.put(state, :queued_data, total_data)}

      {:error, reason} ->
        Logger.error(
          "[Network] [#{peer}] Failed to read incoming packet from #{peer.host} `#{reason}`)"
        )

        {:noreply, state}
    end
  end

  def handle_info({:tcp_closed, _socket}, state = %{peer: peer}) do
    Logger.warn("[Network] [#{peer}] Peer closed connection.")

    {:noreply, Map.put(state, :active, false)}
  end

  @doc """
  If we receive a `send` before secrets are set, we'll send the data directly over the wire.
  """
  def handle_cast({:send, %{data: data}}, state = %{socket: socket, peer: peer}) do
    Logger.debug(
      "[Network] [#{peer}] Sending raw data message of length #{byte_size(data)} byte(s) to #{
        peer.host
      }"
    )

    :ok = :gen_tcp.send(socket, data)

    {:noreply, state}
  end

  @doc """
  If we receive a `send` and we have secrets set, we'll send the message as a framed Eth packet.

  However, if we haven't yet sent a Hello message, we should queue the message and try again later. Most
  servers will disconnect if we send a non-Hello message as our first message.
  """
  def handle_cast(
        {:send, %{packet: {packet_mod, _packet_type, _packet_data}}} = data,
        state = %{peer: peer, active: false}
      )
      when packet_mod != ExWire.Packet.Hello do
    Logger.info(
      "[Network] [#{peer}] Queueing packet #{Atom.to_string(packet_mod)} to #{peer.host}"
    )

    # TODO: Should we monitor this process, etc?
    pid = self()

    spawn(fn ->
      :timer.sleep(500)

      GenServer.cast(pid, data)
    end)

    {:noreply, state}
  end

  def handle_cast(
        {:send, %{packet: {packet_mod, packet_type, packet_data}}},
        state = %{socket: socket, secrets: secrets, peer: peer}
      ) do
    Logger.info(
      "[Network] [#{peer}] Sending packet #{Atom.to_string(packet_mod)} to #{peer.host}"
    )

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
      p2p_version: ExWire.Config.p2p_version(),
      client_id: ExWire.Config.client_id(),
      caps: ExWire.Config.caps(),
      listen_port: ExWire.Config.listen_port(),
      node_id: ExWire.Config.node_id()
    })
  end

  @doc """
  Client function to subscribe to incoming packets.

  A subscription should be in the form of `{:server, server_pid}`, and we will
  send a packet to that server with contents `{:packet, packet, peer}` for
  each received packet.
  """
  @spec subscribe(pid(), {module(), atom(), list()} | {:server, pid()}) :: :ok
  def subscribe(pid, subscription) do
    :ok = GenServer.call(pid, {:subscribe, subscription})
  end
end
