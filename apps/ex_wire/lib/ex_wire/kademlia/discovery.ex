defmodule ExWire.Kademlia.Discovery do
  @moduledoc """
  Module that handles node discovery logic.
  """

  alias ExWire.Kademlia.{RoutingTable, Node}

  @doc """
  Starts discovery round.
  """
  @spec start(RoutingTable.t(), [Node.t()]) :: RoutingTable.t()
  def start(table, bootnodes \\ []) do
    table = add_bootnodes(table, bootnodes)

    this_round_nodes = RoutingTable.discovery_nodes(table)

    Enum.each(this_round_nodes, fn node ->
      find_neighbours(table, node)
    end)

    %{
      table
      | discovery_nodes: table.discovery_nodes ++ this_round_nodes,
        discovery_round: table.discovery_round + 1
    }
  end

  @spec add_bootnodes(RoutingTable.t(), [Node.t()]) :: RoutingTable.t()
  defp add_bootnodes(table, nodes) do
    Enum.reduce(nodes, table, fn node, acc ->
      RoutingTable.refresh_node(acc, node)
    end)
  end

  @spec find_neighbours(RoutingTable.t(), Node.t()) :: :ok
  defp find_neighbours(_table, _node) do
    # TODO send actual request
    :ok
  end
end