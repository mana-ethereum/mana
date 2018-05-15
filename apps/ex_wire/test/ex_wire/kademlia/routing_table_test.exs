defmodule ExWire.Kademlia.RoutingTableTest do
  use ExUnit.Case, async: true

  doctest ExWire.Kademlia.RoutingTable

  alias ExWire.Kademlia.{RoutingTable, Bucket, Node}
  alias ExWire.Kademlia.Config, as: KademliaConfig
  alias ExWire.TestHelper

  setup_all do
    node = TestHelper.random_node()
    table = RoutingTable.new(node)

    {:ok, %{table: table}}
  end

  describe "refresh_node/2" do
    test "adds node to routing table", %{table: table} do
      node = TestHelper.random_node()
      table = RoutingTable.refresh_node(table, node)

      bucket_idx = Node.common_prefix(node, table.current_node)

      assert table.buckets |> Enum.at(bucket_idx) |> Bucket.member?(node)
    end

    test "does not current node to routing table", %{table: table} do
      table = RoutingTable.refresh_node(table, table.current_node)

      assert table.buckets |> Enum.all?(fn bucket -> bucket.nodes |> Enum.empty?() end)
    end
  end

  describe "member?/2" do
    test "finds node in routing table", %{table: table} do
      node = TestHelper.random_node()
      table = RoutingTable.refresh_node(table, node)

      assert RoutingTable.member?(table, node)
    end

    test "does not find node in routing table", %{table: table} do
      node = TestHelper.random_node()

      refute RoutingTable.member?(table, node)
    end
  end

  describe "neighbours/2" do
    test "returns neighbours when there are not enough nodes", %{table: table} do
      node = TestHelper.random_node()

      neighbours =
        table
        |> RoutingTable.refresh_node(node)
        |> RoutingTable.neighbours(node)

      assert Enum.count(neighbours) == 1
      assert List.first(neighbours) == node
    end

    test "returns neighbours based on xor distance" do
      table = TestHelper.random_routing_table()
      node = TestHelper.random_node()

      neighbours = table |> RoutingTable.neighbours(node)

      assert Enum.count(neighbours) == KademliaConfig.bucket_size()
    end
  end
end
