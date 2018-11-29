defmodule ExWire.Kademlia do
  @moduledoc """
  Handles Kademlia algorithm state.
  """

  alias ExWire.Handler.Params
  alias ExWire.Kademlia.{Node, RoutingTable, Server}
  alias ExWire.Message.{FindNeighbours, Neighbours, Pong}
  alias ExWire.Struct.Endpoint

  @doc """
  Adds new node to routing table.
  """
  @spec refresh_node(GenServer.server(), Node.t()) :: :ok
  def refresh_node(server \\ Server.default_process_name(), peer = %Node{}) do
    GenServer.cast(server, {:refresh_node, peer})
  end

  @doc """
  Handles pong message (adds a node to routing table etc).
  """
  @spec handle_pong(Pong.t(), Keyword.t()) :: :ok
  def handle_pong(server \\ Server.default_process_name(), pong = %Pong{}) do
    GenServer.cast(server, {:handle_pong, pong})
  end

  @doc """
  Handles ping message (by adding a node to routing table etc).
  """
  @spec handle_ping(Params.t(), Keyword.t()) :: :ok
  def handle_ping(server \\ Server.default_process_name(), params = %Params{}) do
    GenServer.cast(server, {:handle_ping, params})
  end

  @doc """
  Sends ping to a node saving it to expected pongs.
  """
  @spec ping(Node.t(), Keyword.t()) :: :ok
  def ping(server \\ Server.default_process_name(), node = %Node{}) do
    GenServer.cast(server, {:ping, node})
  end

  @doc """
  Returns current routing table.
  """
  @spec routing_table() :: RoutingTable.t()
  def routing_table(server \\ Server.default_process_name()) do
    GenServer.call(server, :routing_table)
  end

  @doc """
  Returns neighbours of specified node.
  """
  @spec neighbours(FindNeighbours.t(), Endpoint.t(), Keyword.t()) :: [Node.t()]
  def neighbours(server \\ Server.default_process_name(), find_neighbours, endpoint) do
    GenServer.call(server, {:neighbours, find_neighbours, endpoint})
  end

  @doc """
  Receives neighbours request and ping each of them if request is not expired.
  """
  @spec handle_neighbours(Neighbours.t(), Keyword.t()) :: :ok
  def handle_neighbours(server \\ Server.default_process_name(), neighbours) do
    GenServer.cast(server, {:handle_neighbours, neighbours})
  end
end
