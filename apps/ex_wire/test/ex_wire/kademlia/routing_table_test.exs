defmodule ExWire.Kademlia.RoutingTableTest do
  use ExUnit.Case, async: true

  doctest ExWire.Kademlia.RoutingTable

  alias ExWire.Kademlia.{RoutingTable, Bucket, Node}
  alias ExWire.Kademlia.Config, as: KademliaConfig
  alias ExWire.Message.Pong
  alias ExWire.TestHelper
  alias ExWire.Adapter.UDP
  alias ExWire.Network
  alias ExWire.Util.Timestamp
  alias ExWire.Handler.Params

  setup_all do
    {:ok, network_client_pid} =
      UDP.start_link(network_module: {Network, []}, port: 35349, name: :routing_table_test)

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
        1..KademliaConfig.bucket_size()
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

  describe "handle_pong/2" do
    test "does not add node if pong is expired", %{table: table} do
      pong = %Pong{to: TestHelper.random_endpoint(), timestamp: Timestamp.now() - 5, hash: "hey"}
      updated_table = RoutingTable.handle_pong(table, pong)

      assert table == updated_table
    end

    test "adds a new node from pong", %{table: table} do
      pong = %Pong{to: TestHelper.random_endpoint(), timestamp: Timestamp.now() + 5, hash: "hey"}

      params = %Params{
        remote_host: %ExWire.Struct.Endpoint{ip: [1, 2, 3, 4], udp_port: 55},
        signature: <<1>>,
        recovery_id: 3,
        hash: <<5>>,
        data:
          [1, [<<1, 2, 3, 4>>, <<>>, <<5>>], [<<5, 6, 7, 8>>, <<6>>, <<>>], 4] |> ExRLP.encode(),
        timestamp: 123
      }

      updated_table = RoutingTable.handle_pong(table, pong, params)

      node = Node.from_handler_params(params)
      assert RoutingTable.member?(updated_table, node)
    end

    test "refreshes stale node if expected pong was received", %{table: table} do
      # create stale node that will be the oldest in our bucket
      stale_node = TestHelper.random_node()
      bucket_idx = RoutingTable.bucket_id(table, stale_node)

      # create bucket with garbage nodes to make it full and insert our stale bucket
      full_bucket =
        TestHelper.random_bucket(id: bucket_idx, bucket_size: KademliaConfig.bucket_size() - 1)

      full_bucket = %{
        full_bucket
        | nodes: full_bucket.nodes |> List.insert_at(KademliaConfig.bucket_size() - 1, stale_node)
      }

      # new node that we want to insert.. we're using the same key to make a node go to the same bucket
      new_node = %{stale_node | key: stale_node.key <> <<1>>}

      # add stale node's pong to expected pong because bucket is full
      updated_table =
        table
        |> RoutingTable.replace_bucket(bucket_idx, full_bucket)
        |> RoutingTable.refresh_node(new_node)

      # table is receiving pong from stale node
      ping_mdc =
        updated_table.expected_pongs
        |> Enum.map(fn {key, _value} -> key end)
        |> List.first()

      pong = %Pong{
        to: table.current_node.endpoint,
        timestamp: Timestamp.now() + 5,
        hash: ping_mdc
      }

      updated_table1 = RoutingTable.handle_pong(updated_table, pong)

      # stale node should be be the first in bucket
      [^stale_node | _tail] = RoutingTable.nodes_at(updated_table1, bucket_idx)
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
