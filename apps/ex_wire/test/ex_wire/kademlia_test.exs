defmodule ExWire.KademliaTest do
  use ExUnit.Case, async: true

  alias ExWire.{Kademlia, TestHelper}
  alias ExWire.Kademlia.{Server, RoutingTable, Node}
  alias ExWire.Adapter.UDP
  alias ExWire.Network
  alias ExWire.Message.Pong
  alias ExWire.Handler.Params
  alias ExWire.Util.Timestamp

  setup_all do
    node = TestHelper.random_node()

    {:ok, network_client_pid} =
      UDP.start_link(
        network_module: {Network, []},
        port: TestHelper.random(9_999),
        name: :kademlia_test
      )

    {:ok, _} =
      Server.start_link(
        current_node: node,
        network_client_name: network_client_pid,
        name: :kademlia
      )

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

  describe "handle_pong/3" do
    test "adds a node from pong to routing table" do
      pong = %Pong{to: TestHelper.random_endpoint(), timestamp: Timestamp.now() + 5, hash: "hey"}

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
        type: 2
      }

      Kademlia.handle_pong(pong, params)

      node = Node.from_handler_params(params)
      table = Kademlia.routing_table()
      assert table |> RoutingTable.member?(node)
    end
  end

  describe "handle_ping/2" do
    test "adds node from ping params" do
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

      Kademlia.handle_ping(params)

      node = Node.from_handler_params(params)
      table = Kademlia.routing_table()
      assert table |> RoutingTable.member?(node)
    end
  end

  describe "neighbours/2" do
    test "returns neighbours of specified node" do
      node = TestHelper.random_node()

      Kademlia.refresh_node(node)

      assert node |> Kademlia.neighbours() |> Enum.member?(node)
    end
  end
end
