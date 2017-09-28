defmodule ExWire.Adapter.TCP do
  @moduledoc """
  Starts a TCP server to handle incoming and outgoing RLPx connections.
  """
  use GenServer

  alias ExthCrypto.Hash.Keccak

  @doc """
  When starting a TCP server, ...
  """
  def start_link(:outbound, host, port, my_ephemeral_key_pair, my_nonce, auth_data) do
    GenServer.start_link(__MODULE__, %{is_outbound: true, host: host, port: port, my_ephemeral_key_pair: my_ephemeral_key_pair, my_nonce: my_nonce, auth_data: auth_data})
  end

  @doc """
  Initialize by opening up a `gen_tcp` server on a given port.
  """
  def init(state=%{is_outbound: true, host: host, port: port}) do
    {:ok, socket} = :gen_tcp.connect(host |> String.to_charlist, port, [:binary])

    IO.inspect(["Connected socket", socket])

    {:ok, Map.put(state, :socket, socket)}
  end

  @doc """
  Handle info will handle when we have inbound communucation from a peer node.

  Note: all responses will be asynchronous.
  """
  def handle_info(info={:tcp, _socket, data}, state=%{is_outbound: is_outbound, host: host, port: port, auth_data: auth_data, my_ephemeral_key_pair: {my_ephemeral_public_key, my_ephemeral_private_key}, my_nonce: my_nonce}) do
    IO.inspect(["Got inbound message", info, state], limit: :infinity)

    case ExWire.Handshake.read_ack_resp(ack_data=data, ExWire.private_key, host) do
      {:ok, %ExWire.Handshake.AckRespV4{
        remote_ephemeral_public_key: remote_ephemeral_public_key,
        remote_nonce: remote_nonce
      }} ->
        # We're the initiator, by definition since we got an ack resp.

        IO.inspect([my_ephemeral_private_key, remote_ephemeral_public_key], limit: :infinity)
        ephemeral_shared_secret = ExthCrypto.ECIES.ECDH.generate_shared_secret(my_ephemeral_private_key, remote_ephemeral_public_key |> ExthCrypto.Key.raw_to_der)
        # TODO: Nonces will need to be reversed come winter
        shared_secret = Keccak.kec(ephemeral_shared_secret <> Keccak.kec(remote_nonce <> my_nonce))
        token = Keccak.kec(shared_secret)
        aes_secret = Keccak.kec(ephemeral_shared_secret <> shared_secret)
        mac_secret = Keccak.kec(ephemeral_shared_secret <> aes_secret)

        mac_1 =
          Keccak.init_mac()
          |> Keccak.update_mac(:crypto.exor(mac_secret, remote_nonce))
          |> Keccak.update_mac(auth_data)

        mac_2 = Keccak.init_mac()
          |> Keccak.update_mac(:crypto.exor(mac_secret, my_nonce))
          |> Keccak.update_mac(ack_data)

        egress_mac = mac_1
        ingress_mac = mac_2

        IO.inspect(["Set all secrets, go and send a framed message, I dare you."])

        {:noreply, Map.merge(state, %{
          egress_mac: egress_mac,
          ingress_mac: ingress_mac,
          aes_secret: aes_secret,
          mac_secret: mac_secret
          })} |> IO.inspect(limit: :infinity)
      _ ->
        IO.inspect("Unknown message ???")
        {:noreply, state}
    end
  end

  @doc """
  For cast, we'll respond back to a given peer with a given message package. This represents
  all outbound messages we'll ever send.
  """
  def handle_cast({:send, %{data: data}}=info, state = %{socket: socket}) do
    IO.inspect(["Sending outbound message", info, state])

    :ok = :gen_tcp.send(socket, data)

    {:noreply, state}
  end

end