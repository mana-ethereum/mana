defmodule ExWire.Kademlia do
  @moduledoc """
  Handles Kademlia algorithm state.
  """

  alias ExWire.Kademlia.Server
  alias ExWire.Struct.{Peer, RoutingTable}

  @doc """
  Adds new node to routing table.
  """
  @spec add_node(Peer.t(), Keyword.t()) :: :ok
  def add_node(peer = %Peer{}, opts \\ []) do
    opts
    |> process_name()
    |> GenServer.cast({:add_node, peer})
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
  @spec neighbours(Peer.t(), Keyword.t()) :: [Peer.t()]
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
