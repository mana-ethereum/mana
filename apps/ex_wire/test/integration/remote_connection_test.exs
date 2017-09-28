defmodule ExWire.RemoteConnectionTest do
  @moduledoc """
  This test case will connect to a live running node (preferably Geth or Parity).
  We'll attempt to pull blocks from the remote peer.

  Before starting, you'll run to run a Parity or Geth node.

  E.g. `cargo run -- --chain=ropsten --bootnodes=`
  """
  use ExUnit.Case, async: true

  @moduletag integration: true
  @moduletag network: true

  @local_peer [127,0,0,1]
  @local_peer_port 35353
  @local_tcp_port 36363

  @public_node_url "enode://4581188ce6e4af8f6c755481994d7df1532e3a427ee1e48811559f3f778f9727662cbbd7ce0213ebfb246629148958492995ae80bad44b017bd8d160f5789f1d@192.168.1.2:30303"

  def receive(inbound_message, pid) do
    send(pid, {:inbound_message, inbound_message})
  end

  test "connect to remote peer for discovery" do
    %URI{
      scheme: "enode",
      userinfo: remote_id,
      host: remote_host,
      port: remote_peer_port
    } = URI.parse(@public_node_url)

    remote_ip = with {:ok, remote_ip} <- :inet.ip(remote_host |> String.to_charlist) do
      remote_ip |> Tuple.to_list
    end

    remote_peer = %ExWire.Struct.Endpoint{
      ip: remote_ip,
      udp_port: remote_peer_port,
    }

    # First, start a new client
    {:ok, client_pid} = ExWire.Adapter.UDP.start_link({__MODULE__, [self()]}, @local_peer_port)

    # Now, we'll send a ping / pong to verify connectivity
    timestamp = ExWire.Util.Timestamp.soon()

    ping = %ExWire.Message.Ping{
      version: 1,
      from: %ExWire.Struct.Endpoint{ip: @local_peer, tcp_port: @local_tcp_port, udp_port: @local_peer_port},
      to: %ExWire.Struct.Endpoint{ip: remote_ip, tcp_port: nil, udp_port: remote_peer_port},
      timestamp: timestamp,
    }

    ExWire.Network.send(ping, client_pid, remote_peer)

    receive_pong(timestamp, client_pid, remote_peer, remote_id)
  end

  def receive_pong(timestamp, client_pid, remote_peer, remote_id) do
    receive do
      {:inbound_message, inbound_message} ->
        # Check the message looks good
        message = decode_message(inbound_message)

        assert message.__struct__ == ExWire.Message.Pong
        assert %ExWire.Struct.Endpoint{} = message.to
        assert message.timestamp >= timestamp

        # If so, we're going to continue on to "find neighbours."
        find_neighbours = %ExWire.Message.FindNeighbours{
          target: remote_id |> ExthCrypto.Math.hex_to_bin,
          timestamp: ExWire.Util.Timestamp.soon()
        } |> IO.inspect

        ExWire.Network.send(find_neighbours, client_pid, remote_peer)

        receive_neighbours()
      after 2_000 ->
        raise "Expected pong, but did not receive before timeout."
    end
  end

  def receive_neighbours() do
    receive do
      {:inbound_message, inbound_message} ->
        # Check the message looks good
        message = decode_message(inbound_message)

        IO.inspect(["Got neighbors", message], limit: :infinity)
      after 2_000 ->
        raise "Expected neighbours, but did not receive before timeout."
    end
  end

  def decode_message(%ExWire.Network.InboundMessage{
    data: <<
      _hash :: size(256),
      _signature :: size(512),
      _recovery_id:: integer-size(8),
      type:: integer-size(8),
      data :: bitstring
    >>
  }) do
    ExWire.Message.decode(type, data)
  end

  test "connect to remote peer for handshake" do
    %URI{
      scheme: "enode",
      userinfo: remote_id,
      host: remote_host,
      port: remote_peer_port
    } = URI.parse(@public_node_url)

    remote_id = remote_id |> ExthCrypto.Math.hex_to_bin |> ExthCrypto.Key.raw_to_der

    {my_auth_msg, my_ephemeral_key_pair, my_nonce} = ExWire.Handshake.build_auth_msg(
      ExWire.public_key,
      ExWire.private_key,
      remote_id
    )

    {:ok, encoded_auth_msg} = my_auth_msg
      |> ExWire.Handshake.AuthMsgV4.serialize()
      |> ExWire.Handshake.EIP8.wrap_eip_8(remote_id, "1.2.3.4", my_ephemeral_key_pair)

    {:ok, client_pid} = ExWire.Adapter.TCP.start_link(:outbound, remote_host, remote_peer_port, my_ephemeral_key_pair, my_nonce, encoded_auth_msg)

    # Send auth message
    GenServer.cast(client_pid, {:send, %{data: encoded_auth_msg}})

    :timer.sleep(2000)

  end
end