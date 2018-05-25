defmodule ExWire.Kademlia do
  @moduledoc """
  Handles Kademlia algorithm state.
  """

  alias ExWire.Kademlia.{Server, Node, RoutingTable}
  alias ExWire.Message.{Pong, FindNeighbours, Neighbours}
  alias ExWire.Handler.Params
  alias ExWire.Struct.Endpoint

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
  Handles pong message (adds a node to routing table etc).
  """
  @spec handle_pong(Pong.t(), Params.t(), Keyword.t()) :: :ok
  def handle_pong(pong = %Pong{}, params = %Params{}, opts \\ []) do
    opts
    |> process_name()
    |> GenServer.cast({:handle_pong, pong, params})
  end

  @doc """
  Handles ping message (by adding a node to routing table etc).
  """
  @spec handle_ping(Params.t(), Keyword.t()) :: :ok
  def handle_ping(params = %Params{}, opts \\ []) do
    opts
    |> process_name()
    |> GenServer.cast({:handle_ping, params})
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
  @spec neighbours(FindNeighbours.t(), Endpoint.t(), Keyword.t()) :: [Node.t()]
  def neighbours(find_neighbours, endpoint, opts \\ []) do
    opts
    |> process_name()
    |> GenServer.call({:neighbours, find_neighbours, endpoint})
  end

  @doc """
  Receives neighbours request and ping each of them if request is not expired.
  """
  @spec handle_neighbours(Neighbours.t(), Keyword.t()) :: :ok
  def handle_neighbours(neighbours, opts \\ []) do
    opts
    |> process_name()
    |> GenServer.cast({:handle_neighbours, neighbours})
  end

  @spec process_name(Keyword.t()) :: atom()
  defp process_name(opts) do
    opts[:process_name] || Server.default_process_name()
  end
end
