defmodule ExWire.Struct.RoutingTableTest do
  use ExUnit.Case, async: true

  doctest ExWire.Struct.RoutingTable

  alias ExWire.Struct.{RoutingTable, Bucket, Peer}

  describe "add_node/2" do
    setup do
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
  end
end
