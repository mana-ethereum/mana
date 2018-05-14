defmodule ExWire.Kademlia.RoutingTableTest do
  use ExUnit.Case, async: true

  doctest ExWire.Kademlia.RoutingTable

  alias ExWire.Kademlia.{RoutingTable, Bucket, Node}
  alias ExWire.Kademlia.Config, as: KademliaConfig

  setup_all do
    node =
      Node.new(
        <<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79, 124, 126, 164, 120,
          206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48, 148, 233, 203, 201, 33, 110, 122,
          163, 73, 105, 18, 66, 87, 109, 85, 42, 42, 86, 170, 234, 228, 38, 197, 48, 61, 237, 103,
          124, 228, 85, 186, 26, 205, 157>>
      )

    table = RoutingTable.new(node)

    {:ok, %{table: table}}
  end

  describe "refresh_node/2" do
    test "adds node to routing table", %{table: table} do
      node =
        Node.new(
          <<4, 48, 183, 171, 48, 160, 28, 18, 74, 108, 206, 202, 54, 134, 62, 206, 18, 196, 245,
            250, 104, 227, 186, 155, 11, 81, 64, 124, 204, 0, 46, 238, 211, 179, 16, 45, 32, 168,
            143, 28, 29, 60, 49, 84, 226, 68, 147, 23, 184, 239, 149, 9, 14, 119, 179, 18, 213,
            204, 57, 53, 79, 134, 213, 214, 6>>
        )

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
      node =
        Node.new(
          <<4, 48, 183, 171, 48, 160, 28, 18, 74, 108, 206, 202, 54, 134, 62, 206, 18, 196, 245,
            250, 104, 227, 186, 155, 11, 81, 64, 124, 204, 0, 46, 238, 211, 179, 16, 45, 32, 168,
            143, 28, 29, 60, 49, 84, 226, 68, 147, 23, 184, 239, 149, 9, 14, 119, 179, 18, 213,
            204, 57, 53, 79, 134, 213, 214, 6>>
        )

      table = RoutingTable.refresh_node(table, node)

      assert RoutingTable.member?(table, node)
    end

    test "does not find node in routing table", %{table: table} do
      node =
        Node.new(
          <<4, 48, 183, 171, 48, 160, 28, 18, 74, 108, 206, 202, 54, 134, 62, 206, 18, 196, 245,
            250, 104, 227, 186, 155, 11, 81, 64, 124, 204, 0, 46, 238, 211, 179, 16, 45, 32, 168,
            143, 28, 29, 60, 49, 84, 226, 68, 147, 23, 184, 239, 149, 9, 14, 119, 179, 18, 213,
            204, 57, 53, 79, 134, 213, 214, 6>>
        )

      refute RoutingTable.member?(table, node)
    end
  end

  describe "neighbours/2" do
    test "returns neighbours when there are not enough nodes", %{table: table} do
      node =
        Node.new(
          <<4, 48, 183, 171, 48, 160, 28, 18, 74, 108, 206, 202, 54, 134, 62, 206, 18, 196, 245,
            250, 104, 227, 186, 155, 11, 81, 64, 124, 204, 0, 46, 238, 211, 179, 16, 45, 32, 168,
            143, 28, 29, 60, 49, 84, 226, 68, 147, 23, 184, 239, 149, 9, 14, 119, 179, 18, 213,
            204, 57, 53, 79, 134, 213, 214, 6>>
        )

      neighbours =
        table
        |> RoutingTable.refresh_node(node)
        |> RoutingTable.neighbours(node)

      assert Enum.count(neighbours) == 1
      assert List.first(neighbours) == node
    end

    test "returns neighbours based on xor distance" do
      table = random_full_routing_table()
      node = random_peer()

      neighbours = table |> RoutingTable.neighbours(node)

      assert Enum.count(neighbours) == KademliaConfig.bucket_size
    end
  end

  defp random_full_routing_table do
    table = random_peer() |> RoutingTable.new()

    1..(KademliaConfig.bucket_size() * KademliaConfig.id_size())
    |> Enum.reduce(table, fn _el, acc ->
      acc |> RoutingTable.refresh_node(random_peer())
    end)
  end

  defp random_peer do
    Node.new(public_key())
  end

  defp public_key do
    1..64
    |> Enum.reduce(<<>>, fn _el, acc ->
      random = :rand.uniform(256)

      acc <> <<random>>
    end)
  end
end
