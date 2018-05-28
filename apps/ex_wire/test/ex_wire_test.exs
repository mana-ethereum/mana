defmodule ExWireTest do
  use ExUnit.Case
  doctest ExWire

  alias ExWire.{Protocol, Config}
  alias ExWire.Message.Ping
  alias ExWire.Message.Pong
  alias ExWire.Message.Neighbours
  alias ExWire.Message.FindNeighbours
  alias ExWire.Handler.FindNeighbours, as: FindNeighboursHandler
  alias ExWire.Util.Timestamp
  alias ExWire.Struct.Endpoint

  @them %ExWire.Struct.Endpoint{
    ip: [0, 0, 0, 1],
    udp_port: 30303,
    tcp_port: nil
  }

  @us %ExWire.Struct.Endpoint{
    ip: [0, 0, 0, 2],
    udp_port: 30303,
    tcp_port: nil
  }

  setup do
    Process.register(self(), :test)

    :ok
  end

  test "`ping` responds with a `pong`" do
    timestamp = Timestamp.now()

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
    timestamp = Timestamp.now()

    find_neighbours = %FindNeighbours{
      target: <<1>>,
      timestamp: timestamp
    }

    fake_send(find_neighbours, timestamp + 1)

    params = %{data: FindNeighbours.encode(find_neighbours), remote_host: %Endpoint{}}
    neighbours = FindNeighboursHandler.fetch_neighbours(params, [])

    response = %Neighbours{
      nodes: neighbours,
      timestamp: timestamp + 1
    }

    assert_receive_message(response)
  end

  def assert_receive_message(message) do
    message = message |> Protocol.encode(ExWire.Config.private_key())

    assert_receive(%{data: ^message, to: @us})
  end

  def fake_send(message, timestamp) do
    encoded_message = Protocol.encode(message, ExWire.Config.private_key())
    {_, process_name} = Config.udp_network_adapter()

    GenServer.cast(
      process_name,
      {
        :fake_recieve,
        %{
          data: encoded_message,
          remote_host: @us,
          timestamp: timestamp
        }
      }
    )

    <<hash::256, _::binary>> = encoded_message

    hash
  end
end
