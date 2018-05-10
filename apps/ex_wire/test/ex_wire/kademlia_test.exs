defmodule ExWire.KademliaTest do
  use ExUnit.Case, async: true

  alias ExWire.Kademlia
  alias ExWire.Kademlia.Server
  alias ExWire.Struct.{RoutingTable, Peer}

  setup_all do
    node =
      Peer.new(
        "13.84.180.140",
        30303,
        "30b7ab30a01c124a6cceca36863ece12c4f5fa68e3ba9b0b51407ccc002eeed3b3102d20a88f1c1d3c3154e2449317b8ef95090e77b312d5cc39354f86d5d606"
      )

    {:ok, _} = Server.start_link(node)

    :ok
  end

  describe "add_node/2" do
    test "adds node to routing table" do
      node =
        ExWire.Struct.Peer.new(
          "13.84.180.140",
          30303,
          "6ce05930c72abc632c58e2e4324f7c7ea478cec0ed4fa2528982cf34483094e9cbc9216e7aa349691242576d552a2a56aaeae426c5303ded677ce455ba1acd9d"
        )

      Kademlia.add_node(node)

      table = Kademlia.routing_table()

      assert table |> RoutingTable.member?(node)
    end
  end
end
