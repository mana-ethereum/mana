defmodule ExWire.Kademlia do
  @moduledoc """
  Handles Kademlia algorithm state.
  """

  alias ExWire.Kademlia.Server
  alias ExWire.Struct.{Node, RoutingTable}

  @doc """
  Adds new node to routing table.
  """
  @spec refresh_node(Node.t(), Keyword.t()) :: :ok
  def refresh_node(peer = %Node{}, opts \\ []) do
    opts
    |> process_name()
    |> GenServer.cast({:refresh_node, peer})
  end

  @doc """
  Returns current routing table.
  """
  @spec routing_table(Keyword.t()) :: RoutingTable.t()
  def routing_table(opts \\ []) do
    opts
    |> process_name()
    |> GenServer.call(:routing_table)
  end

  @doc """
  Returns neighbours of specified node.
  """
  @spec neighbours(Node.t(), Keyword.t()) :: [Node.t()]
  def neighbours(node, opts \\ []) do
    opts
    |> process_name()
    |> GenServer.call({:neighbours, node})
  end

  @spec process_name(Keyword.t()) :: atom()
  defp process_name(opts) do
    opts[:process_name] || Server.default_process_name()
  end
end
