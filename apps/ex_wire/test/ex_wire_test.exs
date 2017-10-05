defmodule ExWireTest do
  use ExUnit.Case
  doctest ExWire

  alias ExWire.Protocol
  alias ExWire.Message.Ping
  alias ExWire.Message.Pong
  alias ExWire.Message.Neighbours
  alias ExWire.Message.FindNeighbours
  alias ExWire.Util.Timestamp

  @them %ExWire.Struct.Endpoint{
    ip: [0, 0, 0, 1],
    udp_port: 30303,
    tcp_port: nil,
  }

  @us %ExWire.Struct.Endpoint{
    ip: [0, 0, 0, 2],
    udp_port: 30303,
    tcp_port: nil,
  }

  setup do
    Process.register self(), :test

    :ok
  end

  test "`ping` responds with a `pong`" do
    timestamp = Timestamp.now

    ping = %Ping{
      version: 4,
      to: @them,
      from: @us,
      timestamp: timestamp
    }

    hash = fake_send(ping, timestamp + 1)

    assert_receive_message(%Pong{
      to: @us,
      hash: hash,
      timestamp: timestamp + 1
    })
  end

  test "`find_neighbours` responds with `neighbors`" do
    timestamp = Timestamp.now

    find_neighbours = %FindNeighbours{
      target: <<1>>,
      timestamp: timestamp
    }

    fake_send(find_neighbours, timestamp + 1)

    assert_receive_message(%Neighbours{
      nodes: [],
      timestamp: timestamp + 1
    })
  end

  def assert_receive_message(message) do
    message = message |> Protocol.encode(ExWire.Config.private_key())
    assert_receive(%{data: ^message, to: @us})
  end

  def fake_send(message, timestamp) do
    encoded_message = Protocol.encode(message, ExWire.Config.private_key())

    GenServer.cast(
      :test_network_adapter,
      {
        :fake_recieve,
        %{
          data: encoded_message,
          remote_host: @us,
          timestamp: timestamp,
        }
      }
    )

    <<hash::256, _::binary>> = encoded_message

    hash
  end
end
