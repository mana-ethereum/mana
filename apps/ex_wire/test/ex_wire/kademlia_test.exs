defmodule ExWire.KademliaTest do
  use ExUnit.Case, async: true

  alias ExWire.{Kademlia, TestHelper}
  alias ExWire.Kademlia.{Server, RoutingTable, Node}

  setup_all do
    node = TestHelper.random_node()
    {:ok, _} = Server.start_link(node)

    :ok
  end

  describe "refresh_node/2" do
    test "adds node to routing table" do
      node = TestHelper.random_node()

      Kademlia.refresh_node(node)

      table = Kademlia.routing_table()

      assert table |> RoutingTable.member?(node)
    end
  end

  describe "neighbours/2" do
    test "returns neighbours of specified node" do
      node = TestHelper.random_node()

      Kademlia.refresh_node(node)

      [^node] = Kademlia.neighbours(node)
    end
  end
end
