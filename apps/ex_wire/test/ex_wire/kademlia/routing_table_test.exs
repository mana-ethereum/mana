defmodule ExWire.Kademlia.RoutingTableTest do
  use ExUnit.Case, async: true

  doctest ExWire.Kademlia.RoutingTable

  alias ExWire.Kademlia.{RoutingTable, Bucket, Node}
  alias ExWire.Kademlia.Config, as: KademliaConfig
  alias ExWire.TestHelper
  alias ExWire.Adapter.UDP
  alias ExWire.Network

  setup_all do
    {:ok, network_client_pid} = UDP.start_link({Network, []}, 35349)
    node = TestHelper.random_node()
    table = RoutingTable.new(node, network_client_pid)

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

    test "does add removal-insertion node pairs to expected_pongs if bucket is full", %{
      table: table
    } do
      node = TestHelper.random_node()

      bucket_idx = Node.common_prefix(node, table.current_node)
      filler_node = TestHelper.random_node()
      bucket = Enum.at(table.buckets, bucket_idx)

      full_bucket =
        0..(KademliaConfig.bucket_size() + 1)
        |> Enum.reduce(bucket, fn _el, acc -> Bucket.insert_node(acc, filler_node) end)

      updated_table = %{table | buckets: List.replace_at(table.buckets, bucket_idx, full_bucket)}

      table = RoutingTable.refresh_node(updated_table, node)

      pongs = table.expected_pongs
      assert Enum.count(pongs) == 1

      {_mdc, pair} = Enum.at(pongs, 0)
      assert pair == {filler_node, node}
    end
  end

  describe "remove_node/2" do
    test "removes node from routing table", %{table: table} do
      node = TestHelper.random_node()

      table = RoutingTable.refresh_node(table, node)
      assert RoutingTable.member?(table, node)

      table = RoutingTable.remove_node(table, node)
      refute RoutingTable.member?(table, node)
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
      table = TestHelper.random_routing_table(port: TestHelper.random(9_999))
      node = TestHelper.random_node()

      neighbours = table |> RoutingTable.neighbours(node)

      assert Enum.count(neighbours) == KademliaConfig.bucket_size()
    end
  end
end
