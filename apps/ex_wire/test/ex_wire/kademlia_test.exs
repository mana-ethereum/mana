defmodule ExWire.KademliaTest do
  use ExUnit.Case, async: true

  alias ExWire.{Kademlia, TestHelper}
  alias ExWire.Kademlia.{Server, RoutingTable}
  alias ExWire.Adapter.UDP
  alias ExWire.Network

  setup_all do
    node = TestHelper.random_node()
    {:ok, network_client_pid} = UDP.start_link({Network, []}, 35_350)
    {:ok, _} = Server.start_link({node, network_client_pid})

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
