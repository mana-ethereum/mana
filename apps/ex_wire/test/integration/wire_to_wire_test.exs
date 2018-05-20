defmodule WireToWireTest do
  @moduledoc """
  This test starts a server and connects a peer to it. It
  checks that a PING / PONG can be successfully communicated.
  """

  use ExUnit.Case, async: true

  @moduletag integration: true
  @localhost [127, 0, 0, 1]
  @us_port 8888
  @them_port 9999

  setup_all do
    {:ok, server} =
      ExWire.Adapter.UDP.start_link(
        network_module: {ExWire.Network, []},
        port: @them_port,
        name: :wire_to_wire_them
      )

    remote_host = %ExWire.Struct.Endpoint{
      ip: @localhost,
      udp_port: @them_port
    }

    {:ok, %{server: server, remote_host: remote_host}}
  end

  def receive(inbound_message, pid) do
    send(pid, {:inbound_message, inbound_message})
  end

  test "ping / pong", %{remote_host: remote_host} do
    {:ok, client_pid} =
      ExWire.Adapter.UDP.start_link(
        network_module: {__MODULE__, [self()]},
        port: @us_port,
        name: :wire_to_wire
      )

    timestamp = ExWire.Util.Timestamp.now()

    ping = %ExWire.Message.Ping{
      version: 1,
      from: %ExWire.Struct.Endpoint{ip: @localhost, tcp_port: nil, udp_port: @us_port},
      to: %ExWire.Struct.Endpoint{ip: @localhost, tcp_port: nil, udp_port: @them_port},
      timestamp: timestamp
    }

    ExWire.Network.send(ping, client_pid, remote_host)

    receive do
      {:inbound_message, inbound_message} ->
        message = decode_message(inbound_message)

        assert message.__struct__ == ExWire.Message.Pong

        assert message.to == %ExWire.Struct.Endpoint{
                 ip: [127, 0, 0, 1],
                 tcp_port: nil,
                 udp_port: @us_port
               }

        assert message.timestamp >= timestamp
    after
      2_000 ->
        raise "Expected pong, but did not receive before timeout."
    end
  end

  def decode_message(%ExWire.Network.InboundMessage{
        data: <<
          _hash::size(256),
          _signature::size(512),
          _recovery_id::integer-size(8),
          type::integer-size(8),
          data::bitstring
        >>
      }) do
    ExWire.Message.decode(type, data)
  end
end
