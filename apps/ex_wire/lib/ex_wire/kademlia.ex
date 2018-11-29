defmodule ExWire.Kademlia do
  @moduledoc """
  Handles Kademlia algorithm state. also a GenServer that manages Kademlia state.
  """

  alias ExWire.Handler.Params
  alias ExWire.Kademlia.{Node, RoutingTable}
  alias ExWire.Message.{FindNeighbours, Neighbours, Pong}
  alias ExWire.Struct.Endpoint

  @doc """
  Adds new node to routing table.
  """
  @spec refresh_node(Node.t()) :: :ok
  @spec refresh_node(GenServer.server(), Node.t()) :: :ok
  def refresh_node(server \\ __MODULE__, peer = %Node{}) do
    GenServer.cast(server, {:refresh_node, peer})
  end

  @doc """
  Handles pong message (adds a node to routing table etc).
  """
  @spec handle_pong(Pong.t(), Keyword.t()) :: :ok
  @spec handle_pong(GenServer.server(), Pong.t()) :: :ok
  def handle_pong(server \\ __MODULE__, pong = %Pong{}) do
    GenServer.cast(server, {:handle_pong, pong})
  end

  @doc """
  Handles ping message (by adding a node to routing table etc).
  """
  @spec handle_ping(Params.t(), Keyword.t()) :: :ok
  @spec handle_ping(GenServer.server(), Params.t()) :: :ok
  def handle_ping(server \\ __MODULE__, params = %Params{}) do
    GenServer.cast(server, {:handle_ping, params})
  end

  @doc """
  Sends ping to a node saving it to expected pongs.
  """
  @spec ping(Node.t(), Keyword.t()) :: :ok
  @spec ping(GenServer.server(), Node.t()) :: :ok
  def ping(server \\ __MODULE__, node = %Node{}) do
    GenServer.cast(server, {:ping, node})
  end

  @doc """
  Returns current routing table.
  """
  @spec routing_table() :: RoutingTable.t()
  @spec routing_table(GenServer.server()) :: RoutingTable.t()
  def routing_table(server \\ __MODULE__) do
    GenServer.call(server, :routing_table)
  end

  @doc """
  Returns neighbours of specified node.
  """
  @spec neighbours(GenServer.server(), FindNeighbours.t(), Endpoint.t()) :: [Node.t()]
  @spec neighbours(FindNeighbours.t(), Endpoint.t()) :: [Node.t()]
  def neighbours(server \\ __MODULE__, find_neighbours, endpoint) do
    GenServer.call(server, {:neighbours, find_neighbours, endpoint})
  end

  @doc """
  Receives neighbours request and ping each of them if request is not expired.
  """
  @spec handle_neighbours(Neighbours.t()) :: :ok
  @spec handle_neighbours(GenServer.server(), Neighbours.t()) :: :ok
  def handle_neighbours(server \\ __MODULE__, neighbours) do
    GenServer.cast(server, {:handle_neighbours, neighbours})
  end

  use GenServer

  alias ExWire.Kademlia.{Discovery, Node, RoutingTable}

  @type state :: %{
          routing_table: RoutingTable.t(),
          ignore_pongs: boolean()
        }

  @max_discovery_rounds 7

  # 5s
  @discovery_round_period 5_000

  # 10s
  @pong_cleanup_period 10_000

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(params) do
    name = Keyword.get(params, :name, __MODULE__)
    network_client_name = Keyword.fetch!(params, :network_client_name)
    current_node = Keyword.fetch!(params, :current_node)
    nodes = Keyword.get(params, :nodes, [])

    GenServer.start_link(__MODULE__, {current_node, network_client_name, nodes}, name: name)
  end

  @impl true
  def init({current_node = %Node{}, network_client_name, nodes}) do
    routing_table = RoutingTable.new(current_node, network_client_name)

    _ = schedule_discovery_round(0, nodes)
    schedule_pongs_cleanup()

    {:ok, %{routing_table: routing_table}}
  end

  @impl true
  def handle_cast({:refresh_node, node}, state = %{routing_table: table}) do
    updated_table = RoutingTable.refresh_node(table, node)

    {:noreply, %{state | routing_table: updated_table}}
  end

  def handle_cast(
        {:handle_pong, pong},
        state = %{routing_table: table}
      ) do
    updated_table =
      if Map.get(state, :ignore_pongs, false) do
        table
      else
        RoutingTable.handle_pong(table, pong)
      end

    {:noreply, %{state | routing_table: updated_table}}
  end

  def handle_cast({:handle_ping, params}, state = %{routing_table: table}) do
    updated_table = RoutingTable.handle_ping(table, params)

    {:noreply, %{state | routing_table: updated_table}}
  end

  def handle_cast({:ping, node}, state = %{routing_table: table}) do
    updated_table = RoutingTable.ping(table, node)

    {:noreply, %{state | routing_table: updated_table}}
  end

  def handle_cast({:handle_neighbours, neighbours}, state = %{routing_table: table}) do
    updated_table = RoutingTable.handle_neighbours(table, neighbours)

    {:noreply, %{state | routing_table: updated_table}}
  end

  def handle_cast({:set_ignore_pongs, ignore_pongs}, state) do
    {:noreply, Map.put(state, :ignore_pongs, ignore_pongs)}
  end

  @impl true
  def handle_call(:routing_table, _from, state = %{routing_table: routing_table}) do
    {:reply, routing_table, state}
  end

  def handle_call(
        {:neighbours, find_neighbours, endpoint},
        _from,
        state = %{routing_table: routing_table}
      ) do
    neighbours = RoutingTable.neighbours(routing_table, find_neighbours, endpoint)

    {:reply, neighbours, state}
  end

  @impl true
  def handle_info({:discovery_round, nodes}, state = %{routing_table: routing_table}) do
    updated_table = Discovery.start(routing_table, nodes)

    _ = schedule_discovery_round(updated_table.discovery_round)

    {:noreply, %{state | routing_table: updated_table}}
  end

  def handle_info(:remove_expired_nodes, state = %{routing_table: table}) do
    updated_table = RoutingTable.remove_expired_pongs(table)

    schedule_pongs_cleanup()

    {:noreply, %{state | routing_table: updated_table}}
  end

  @spec schedule_discovery_round(integer(), list(Node.t())) :: reference() | :ok
  defp schedule_discovery_round(round, nodes \\ []) do
    if round <= @max_discovery_rounds do
      Process.send_after(self(), {:discovery_round, nodes}, @discovery_round_period)
    else
      :ok
    end
  end

  @spec schedule_pongs_cleanup() :: reference()
  defp schedule_pongs_cleanup() do
    Process.send_after(self(), :remove_expired_nodes, @pong_cleanup_period)
  end
end
