defmodule ExWire.Handler.FindNeighboursTest do
  use ExUnit.Case, async: true
  doctest ExWire.Handler.FindNeighbours

  test "handler for a `FindNeighbors` message" do
    {:ok, kademlia_process} =
      ExWire.FakeKademliaServer.start_link([
        %ExWire.Kademlia.Node{
          public_key: <<1::256>>,
          key: <<1::160>>,
          endpoint: %ExWire.Struct.Endpoint{
            ip: [52, 169, 14, 227],
            tcp_port: nil,
            udp_port: 30303
          }
        }
      ])

    ExWire.Handler.FindNeighbours.handle(
      %ExWire.Handler.Params{
        remote_host: %ExWire.Struct.Endpoint{ip: [1, 2, 3, 4], udp_port: 55},
        signature: 2,
        recovery_id: 3,
        hash: <<5>>,
        data: [<<1>>, 2] |> ExRLP.encode(),
        timestamp: 7
      },
      kademlia_process_name: kademlia_process
    )

    %ExWire.Message.Neighbours{
      nodes: [
        %ExWire.Struct.Neighbour{
          endpoint: %ExWire.Struct.Endpoint{
            ip: [52, 169, 14, 227],
            tcp_port: nil,
            udp_port: 30303
          },
          node: <<1::256>>
        }
      ],
      timestamp: 7
    }
  end
end
