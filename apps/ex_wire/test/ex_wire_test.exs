defmodule ExWireTest do
  use ExUnit.Case
  doctest ExWire

  alias ExWire.Adapter.Test
  alias ExWire.Handler.FindNeighbours, as: FindNeighboursHandler
  alias ExWire.Message.{FindNeighbours, Neighbours, Ping, Pong}
  alias ExWire.{Network, Protocol, TestHelper}
  alias ExWire.Struct.Endpoint
  alias ExWire.Util.Timestamp

  @them %ExWire.Struct.Endpoint{
    ip: [0, 0, 0, 1],
    udp_port: 30_303,
    tcp_port: nil
  }

  @us %ExWire.Struct.Endpoint{
    ip: [0, 0, 0, 2],
    udp_port: 30_303,
    tcp_port: nil
  }

  setup do
    Process.register(self(), :test)

    {:ok, _network_client_pid} =
      Test.start_link(
        network_module: {Network, []},
        port: TestHelper.random_port_number(),
        name: :ex_wire_test
      )

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

    {:ok, kademlia_process} =
      ExWire.FakeKademliaServer.start_link([
        %ExWire.Kademlia.Node{
          public_key: <<1::256>>,
          key: <<1::160>>,
          endpoint: %ExWire.Struct.Endpoint{
            ip: [52, 169, 14, 227],
            tcp_port: nil,
            udp_port: 30_303
          }
        }
      ])

    fake_send(find_neighbours, timestamp + 1, kademlia_process_name: kademlia_process)

    params = %{data: FindNeighbours.encode(find_neighbours), remote_host: %Endpoint{}}

    neighbours =
      FindNeighboursHandler.fetch_neighbours(params, kademlia_process_name: kademlia_process)

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

  def fake_send(message, timestamp, options \\ []) do
    encoded_message = Protocol.encode(message, ExWire.Config.private_key())

    GenServer.cast(:ex_wire_test, {
      :fake_receive,
      %{
        data: encoded_message,
        remote_host: @us,
        timestamp: timestamp
      },
      options
    })

    <<hash::256, _::binary>> = encoded_message

    hash
  end
end
