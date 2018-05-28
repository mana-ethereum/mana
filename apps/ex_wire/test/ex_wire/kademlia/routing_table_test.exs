defmodule ExWire.Kademlia.RoutingTableTest do
  use ExUnit.Case, async: true

  doctest ExWire.Kademlia.RoutingTable

  alias ExWire.Kademlia.{RoutingTable, Bucket, Node}
  alias ExWire.Kademlia.Config, as: KademliaConfig
  alias ExWire.Message.{Pong, FindNeighbours, Neighbours}
  alias ExWire.TestHelper
  alias ExWire.Util.Timestamp
  alias ExWire.Handler.Params
  alias ExWire.Struct.Neighbour

  setup_all do
    table = TestHelper.random_empty_table()

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

    test "adds pinged node if pong was received", %{table: table} do
      node = TestHelper.random_node()
      table = RoutingTable.ping(table, node)
      mdc = table.expected_pongs |> Enum.map(fn {key, _value} -> key end) |> List.first()

      pong = %Pong{
        to: table.current_node.endpoint,
        timestamp: Timestamp.now() + 5,
        hash: mdc
      }

      updated_table = RoutingTable.handle_pong(table, pong)
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

  describe "handle_ping/2" do
    test "adds nodes from ping params", %{table: table} do
      params = %Params{
        remote_host: %ExWire.Struct.Endpoint{ip: [1, 2, 3, 4], udp_port: 55},
        signature:
          <<193, 30, 149, 122, 226, 192, 230, 158, 118, 204, 173, 80, 63, 232, 67, 152, 216, 249,
            89, 52, 162, 92, 233, 201, 177, 108, 63, 120, 152, 134, 149, 220, 73, 198, 29, 93,
            218, 123, 50, 70, 8, 202, 17, 171, 67, 245, 70, 235, 163, 158, 201, 246, 223, 114,
            168, 7, 7, 95, 9, 53, 165, 8, 177, 13>>,
        recovery_id: 1,
        hash: <<5>>,
        data:
          [1, [<<1, 2, 3, 4>>, <<>>, <<5>>], [<<5, 6, 7, 8>>, <<6>>, <<>>], 4] |> ExRLP.encode(),
        timestamp: 123,
        type: 1
      }

      updated_table = RoutingTable.handle_ping(table, params)

      node = Node.from_handler_params(params)
      assert RoutingTable.member?(updated_table, node)
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
      find_neighbours = %FindNeighbours{target: node.public_key, timestamp: Timestamp.soon()}

      neighbours =
        table
        |> RoutingTable.refresh_node(node)
        |> RoutingTable.neighbours(find_neighbours, node.endpoint)

      assert Enum.count(neighbours) == 1
      assert List.first(neighbours) == node
    end

    test "returns neighbours based on common_prefix distance" do
      table = TestHelper.random_routing_table(port: 35_249)
      node = TestHelper.random_node()
      find_neighbours = %FindNeighbours{target: node.public_key, timestamp: Timestamp.soon()}

      naive_neighbours =
        table.buckets
        |> Enum.flat_map(fn bucket -> bucket.nodes end)
        |> Enum.sort_by(&Node.common_prefix(&1, node), &>=/2)
        |> Enum.take(KademliaConfig.bucket_size())

      neighbours = RoutingTable.neighbours(table, find_neighbours, node.endpoint)

      assert neighbours == naive_neighbours
    end

    test "returns empty list of request is expired", %{table: table} do
      node = TestHelper.random_node()
      find_neighbours = %FindNeighbours{target: node.public_key, timestamp: Timestamp.now() - 5}

      neighbours =
        table
        |> RoutingTable.refresh_node(node)
        |> RoutingTable.neighbours(find_neighbours, node.endpoint)

      assert neighbours == []
    end
  end

  describe "handle_neighbours/2" do
    test "pings received neighbours and saves them to expected_pongs", %{table: table} do
      nodes = 1..5 |> Enum.reduce([], fn _el, acc -> acc ++ [TestHelper.random_node()] end)

      neighbours =
        Enum.map(nodes, fn node -> %Neighbour{node: node.public_key, endpoint: node.endpoint} end)

      neighbours_message = %Neighbours{nodes: neighbours, timestamp: Timestamp.now() + 5}

      updated_table = RoutingTable.handle_neighbours(table, neighbours_message)

      expected_pong_nodes =
        updated_table.expected_pongs
        |> Enum.map(fn {_key, {value, _}} ->
          value
        end)

      assert nodes |> Enum.all?(fn node -> Enum.member?(expected_pong_nodes, node) end)
    end

    test "does node pings nodes from expired request", %{table: table} do
      nodes = 1..5 |> Enum.reduce([], fn _el, acc -> acc ++ [TestHelper.random_node()] end)

      neighbours =
        Enum.map(nodes, fn node -> %Neighbour{node: node.public_key, endpoint: node.endpoint} end)

      neighbours_message = %Neighbours{nodes: neighbours, timestamp: Timestamp.now() - 5}

      updated_table = RoutingTable.handle_neighbours(table, neighbours_message)

      expected_pong_nodes =
        updated_table.expected_pongs
        |> Enum.map(fn {_key, value} ->
          value
        end)

      assert Enum.empty?(expected_pong_nodes)
    end
  end

  describe "discovery_nodes/1" do
    test "returns not used discovery nodes", %{table: table} do
      node1 = TestHelper.random_node()
      node2 = TestHelper.random_node()

      table =
        %{table | discovery_nodes: [node1]}
        |> RoutingTable.refresh_node(node1)
        |> RoutingTable.refresh_node(node2)

      assert [node2] == RoutingTable.discovery_nodes(table)
    end
  end
end
