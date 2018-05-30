defmodule ExWire.Kademlia.DiscoveryTest do
  use ExUnit.Case, async: true
  alias ExWire.TestHelper
  alias ExWire.Kademlia.{Discovery, RoutingTable}

  setup_all do
    table = TestHelper.random_empty_table()

    {:ok, %{table: table}}
  end

  describe "start/2" do
    test "starts new discovery round", %{table: table} do
      bootnodes = Enum.reduce(1..3, [], fn _, acc -> acc ++ [TestHelper.random_node()] end)

      updated_table = Discovery.start(table, bootnodes)

      assert updated_table.discovery_round == 1
      assert Enum.all?(bootnodes, &Enum.member?(updated_table.discovery_nodes, &1))
      assert Enum.all?(bootnodes, &RoutingTable.member?(updated_table, &1))
    end
  end
end
