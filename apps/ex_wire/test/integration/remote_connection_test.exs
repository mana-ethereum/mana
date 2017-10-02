defmodule ExWire.RemoteConnectionTest do
  @moduledoc """
  This test case will connect to a live running node (preferably Geth or Parity).
  We'll attempt to pull blocks from the remote peer.

  Before starting, you'll run to run a Parity or Geth node.

  E.g. `cargo run -- --chain=ropsten --bootnodes=`
  E.g. `cargo run -- --chain=ropsten --bootnodes= --logging network,discovery=trace`
  """
  use ExUnit.Case, async: true

  require Logger

  alias ExWire.Packet

  @moduletag integration: true
  @moduletag network: true

  @local_peer [127,0,0,1]
  @local_peer_port 35353
  @local_tcp_port 36363

  @public_node_url "enode://4581188ce6e4af8f6c755481994d7df1532e3a427ee1e48811559f3f778f9727662cbbd7ce0213ebfb246629148958492995ae80bad44b017bd8d160f5789f1d@127.0.0.1:30303"

  def receive(inbound_message, pid) do
    send(pid, {:inbound_message, inbound_message})
  end

  def receive_packet(inbound_packet, pid) do
    send(pid, {:incoming_packet, inbound_packet})
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

    {:ok, client_pid} = ExWire.Adapter.TCP.start_link(:outbound, remote_host, remote_peer_port, remote_id)

    ExWire.Adapter.TCP.subscribe(client_pid, __MODULE__, :receive_packet, [self()])
    ExWire.Adapter.TCP.send_packet(client_pid, %ExWire.Packet.GetBlockHeaders{block_identifier: 0, max_headers: 1, skip: 0, reverse: false})

    receive_block_headers(client_pid)
  end

  def receive_block_headers(client_pid) do
    receive do
      {:incoming_packet, _packet=%Packet.BlockHeaders{headers: [header]}} ->
        ExWire.Adapter.TCP.send_packet(client_pid, %ExWire.Packet.GetBlockBodies{hashes: [header |> Block.Header.hash]})

        receive_block_bodies(client_pid)
      {:incoming_packet, packet} ->
        # Logger.debug("Expecting block headers packet, got: #{inspect packet}")

        receive_block_headers(client_pid)
      after 2_000 ->
        raise "Expected block headers, but did not receive before timeout."
    end
  end

  def receive_block_bodies(client_pid) do
    receive do
      {:incoming_packet, _packet=%Packet.BlockBodies{blocks: [block]}} ->
        # This is a genesis block
        assert block.transaction_list == []
        assert block.uncle_list == []
      {:incoming_packet, packet} ->
        # Logger.debug("Expecting block bodies packet, got: #{inspect packet}")

        receive_block_bodies(client_pid)
      after 2_000 ->
        raise "Expected block headers, but did not receive before timeout."
    end
  end
end