defmodule ExDevp2pTest do
  alias ExDevp2p.Protocol
  alias ExDevp2p.Messages.Ping
  alias ExDevp2p.Messages.Pong
  alias ExDevp2p.Messages.Neighbors
  alias ExDevp2p.Messages.FindNeighbors
  alias ExDevp2p.Utils.Timestamp
  use ExUnit.Case, async: true
  doctest ExDevp2p

  @them %{
    ip: {0, 0, 0, 1},
    udp_port: 30303,
    tcp_port: nil,
  }

  @us %{
    ip: {0, 0, 0, 2},
    udp_port: 30303,
    tcp_port: nil,
  }

  setup do
    Process.register self(), :test

    :ok
  end

  test "`ping` responds with a `pong` " do
    timestamp = Timestamp.now

    ping = %Ping{
      version: 4,
      to: @them,
      from: @us,
      timestamp: timestamp
    }

    fake_send(ping)

    assert_recieve_message(%Pong{
      to: @us,
      hash: Protocol.hash(ping),
      timestamp: timestamp
    })

  end

  test "`find_neighbours` responds with `neighbors` " do
    timestamp = Timestamp.now

    find_neighbors = %FindNeighbors{
      node_id: 1,
      timestamp: timestamp
    }

    fake_send(find_neighbors)

    assert_recieve_message(%Neighbors{
      node_ids: [],
      timestamp: timestamp
    })
  end

  def assert_recieve_message(message) do
    message = message |> Protocol.encode
    assert_receive(%{data: ^message, to: @us})
  end

  def fake_send(message) do
    GenServer.cast(
      :test_network_adapter,
      {
        :fake_recieve,
        %{
          data: Protocol.encode(message),
          remote_host: @us,
        }
      }
    )
  end
end
