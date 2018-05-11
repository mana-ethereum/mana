defmodule ExWire.Struct.RoutingTableTest do
  use ExUnit.Case, async: true

  doctest ExWire.Struct.RoutingTable

  alias ExWire.Struct.{RoutingTable, Bucket, Peer}
  alias ExWire.KademliaConfig

  setup_all do
    node =
      ExWire.Struct.Peer.new(
        "13.84.180.240",
        30303,
        "6ce05930c72abc632c58e2e4324f7c7ea478cec0ed4fa2528982cf34483094e9cbc9216e7aa349691242576d552a2a56aaeae426c5303ded677ce455ba1acd9d",
        time: :test
      )

    table = node |> ExWire.Struct.RoutingTable.new()

    {:ok, %{table: table}}
  end

  describe "add_node/2" do
    test "adds node to routing table", %{table: table} do
      node =
        ExWire.Struct.Peer.new(
          "13.84.180.140",
          30303,
          "30b7ab30a01c124a6cceca36863ece12c4f5fa68e3ba9b0b51407ccc002eeed3b3102d20a88f1c1d3c3154e2449317b8ef95090e77b312d5cc39354f86d5d606",
          time: :test
        )

      table = table |> RoutingTable.add_node(node)

      bucket_idx = node |> Peer.common_prefix(table.current_node)

      assert table.buckets |> Enum.at(bucket_idx) |> Bucket.member?(node)
    end

    test "does not current node to routing table", %{table: table} do
      table = table |> RoutingTable.add_node(table.current_node)

      assert table.buckets |> Enum.all?(fn bucket -> bucket.nodes |> Enum.empty?() end)
    end
  end

  describe "member?/2" do
    test "finds node in routing table", %{table: table} do
      node =
        ExWire.Struct.Peer.new(
          "13.84.180.140",
          30303,
          "30b7ab30a01c124a6cceca36863ece12c4f5fa68e3ba9b0b51407ccc002eeed3b3102d20a88f1c1d3c3154e2449317b8ef95090e77b312d5cc39354f86d5d606",
          time: :test
        )

      table = table |> RoutingTable.add_node(node)

      assert RoutingTable.member?(table, node)
    end

    test "does not find node in routing table", %{table: table} do
      node =
        ExWire.Struct.Peer.new(
          "13.84.180.140",
          30303,
          "30b7ab30a01c124a6cceca36863ece12c4f5fa68e3ba9b0b51407ccc002eeed3b3102d20a88f1c1d3c3154e2449317b8ef95090e77b312d5cc39354f86d5d606",
          time: :test
        )

      refute RoutingTable.member?(table, node)
    end
  end

  describe "neighbours/2" do
    test "returns neighbours when there are not enough nodes", %{table: table} do
      node =
        ExWire.Struct.Peer.new(
          "13.84.180.140",
          30303,
          "30b7ab30a01c124a6cceca36863ece12c4f5fa68e3ba9b0b51407ccc002eeed3b3102d20a88f1c1d3c3154e2449317b8ef95090e77b312d5cc39354f86d5d606",
          time: :test
        )

      neighbours =
        table
        |> RoutingTable.add_node(node)
        |> RoutingTable.neighbours(node)

      assert Enum.count(neighbours) == 1
      assert List.first(neighbours) == node
    end

    test "returns neighbours bases on xor distance" do
      table = random_full_routing_table()
      node = random_peer()

      naive_neighbours =
        table.buckets
        |> Enum.flat_map(&Bucket.nodes/1)
        |> Enum.sort_by(&Peer.distance(&1, node))
        |> Enum.take(KademliaConfig.id_size())

      neighbours =
        table
        |> RoutingTable.neighbours(node)

      assert Enum.count(neighbours) == Enum.count(naive_neighbours)

      assert Enum.all?(naive_neighbours, fn naive_neighbour ->
               Enum.any?(neighbours, &Peer.equal?(&1, naive_neighbour))
             end)
    end
  end

  defp random_full_routing_table do
    table = random_peer() |> RoutingTable.new()

    1..(KademliaConfig.bucket_size() * KademliaConfig.id_size())
    |> Enum.reduce(table, fn _el, acc ->
      acc |> RoutingTable.add_node(random_peer())
    end)
  end

  defp random_peer do
    %Peer{
      host: "1.1.1.1",
      port: 30303,
      remote_id: random_id(),
      ident: "",
      last_seen: 1
    }
  end

  defp random_id do
    1..64
    |> Enum.reduce(<<>>, fn _el, acc ->
      random = :rand.uniform(256)

      acc <> <<random>>
    end)
  end
end
