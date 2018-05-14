defmodule ExWire.KademliaTest do
  use ExUnit.Case, async: true

  alias ExWire.Kademlia
  alias ExWire.Kademlia.{Server, RoutingTable, Node}

  setup_all do
    node =
      Node.new(
        <<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79, 124, 126, 164, 120,
          206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48, 148, 233, 203, 201, 33, 110, 122,
          163, 73, 105, 18, 66, 87, 109, 85, 42, 42, 86, 170, 234, 228, 38, 197, 48, 61, 237, 103,
          124, 228, 85, 186, 26, 205, 157>>
      )

    {:ok, _} = Server.start_link(node)

    :ok
  end

  describe "refresh_node/2" do
    test "adds node to routing table" do
      node =
        Node.new(
          <<4, 48, 183, 171, 48, 160, 28, 18, 74, 108, 206, 202, 54, 134, 62, 206, 18, 196, 245,
            250, 104, 227, 186, 155, 11, 81, 64, 124, 204, 0, 46, 238, 211, 179, 16, 45, 32, 168,
            143, 28, 29, 60, 49, 84, 226, 68, 147, 23, 184, 239, 149, 9, 14, 119, 179, 18, 213,
            204, 57, 53, 79, 134, 213, 214, 6>>
        )

      Kademlia.refresh_node(node)

      table = Kademlia.routing_table()

      assert table |> RoutingTable.member?(node)
    end
  end

  describe "neighbours/2" do
    test "returns neighbours of specified node" do
      node =
        Node.new(
          <<4, 48, 183, 171, 48, 160, 28, 18, 74, 108, 206, 202, 54, 134, 62, 206, 18, 196, 245,
            250, 104, 227, 186, 155, 11, 81, 64, 124, 204, 0, 46, 238, 211, 179, 16, 45, 32, 168,
            143, 28, 29, 60, 49, 84, 226, 68, 147, 23, 184, 239, 149, 9, 14, 119, 179, 18, 213,
            204, 57, 53, 79, 134, 213, 214, 6>>
        )

      Kademlia.refresh_node(node)

      [^node] = Kademlia.neighbours(node)
    end
  end
end
