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
  alias ExWire.Adapter.TCP

  @moduletag integration: true
  @moduletag network: true

  @local_peer [127,0,0,1]
  @local_peer_port 35353
  @local_tcp_port 36363

  # Local Parity
  # @public_node_url "enode://4581188ce6e4af8f6c755481994d7df1532e3a427ee1e48811559f3f778f9727662cbbd7ce0213ebfb246629148958492995ae80bad44b017bd8d160f5789f1d@127.0.0.1:30303"

  # Local Geth
  # @public_node_url "enode://78251af55c063e9971705721a67ce1a1c538b560fa6fc7ad64680c86cbaa79cacd893d4b29b7ac2a2298e9725b1db429b892387013f01b44f535fc72f30b0945@127.0.0.1:31313"

  # Remote Geth
  @public_node_url "enode://20c9ad97c081d63397d7b685a412227a40e23c8bdc6688c6f37e97cfbc22d2b4d1db1510d8f61e6a8866ad7f0e17c02b14182d37ea7c3c8b9c2683aeb6b733a1@52.169.14.227:30303"

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

    {:ok, client_pid} = TCP.start_link(:outbound, remote_host, remote_peer_port, remote_id)

    TCP.subscribe(client_pid, __MODULE__, :receive_packet, [self()])

    receive_status(client_pid)
  end

  def receive_status(client_pid) do
    receive do
      {:incoming_packet, _packet=%Packet.Status{best_hash: _best_hash, total_difficulty: total_difficulty, genesis_hash: genesis_hash}} ->
        # Send a simple status message
        TCP.send_packet(client_pid, %Packet.Status{
          protocol_version: ExWire.Config.protocol_version(),
          network_id: ExWire.Config.network_id(),
          total_difficulty: total_difficulty,
          best_hash: genesis_hash,
          genesis_hash: genesis_hash
        })

        ExWire.Adapter.TCP.send_packet(client_pid, %ExWire.Packet.GetBlockHeaders{
          block_identifier: genesis_hash,
          max_headers: 1,
          skip: 0,
          reverse: false
        })

        receive_block_headers(client_pid)
      {:incoming_packet, packet} ->
        if System.get_env("TRACE"), do: Logger.debug("Expecting status packet, got: #{inspect packet}")

        receive_status(client_pid)
      after 3_000 ->
        raise "Expected status, but did not receive before timeout."
    end
  end

  def receive_block_headers(client_pid) do
    receive do
      {:incoming_packet, _packet=%Packet.BlockHeaders{headers: [header]}} ->
        ExWire.Adapter.TCP.send_packet(client_pid, %ExWire.Packet.GetBlockBodies{hashes: [header |> Block.Header.hash]})

        receive_block_bodies(client_pid)
      {:incoming_packet, packet} ->
        if System.get_env("TRACE"), do: Logger.debug("Expecting block headers packet, got: #{inspect packet}")

        receive_block_headers(client_pid)
      after 3_000 ->
        raise "Expected block headers, but did not receive before timeout."
    end
  end

  def receive_block_bodies(client_pid) do
    receive do
      {:incoming_packet, _packet=%Packet.BlockBodies{blocks: [block]}} ->
        # This is a genesis block
        assert block.transaction_list == []
        assert block.uncle_list == []

        Logger.warn("Successfully received genesis block from peer.")
      {:incoming_packet, packet} ->
        if System.get_env("TRACE"), do: Logger.debug("Expecting block bodies packet, got: #{inspect packet}")

        receive_block_bodies(client_pid)
      after 3_000 ->
        raise "Expected block bodies, but did not receive before timeout."
    end
  end
end