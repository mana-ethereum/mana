defmodule ExWire.Kademlia.Server do
  use GenServer

  @moduledoc false

  @default_process_name KademliaState
  @max_discovery_rounds 7
  # 5s
  @discovery_round_period 5 * 1000

  alias ExWire.Kademlia.{RoutingTable, Node, Discovery}

  def start_link(params) do
    name = params[:name] || @default_process_name
    network_client_name = Keyword.fetch!(params, :network_client_name)
    current_node = Keyword.fetch!(params, :current_node)
    nodes = params[:nodes] || []

    GenServer.start_link(__MODULE__, {current_node, network_client_name, nodes}, name: name)
  end

  def init({current_node = %Node{}, network_client_name, nodes}) do
    routing_table = RoutingTable.new(current_node, network_client_name)

    schedule_discovery_round(0, nodes)

    {:ok, %{routing_table: routing_table}}
  end

  def handle_cast({:refresh_node, node}, %{routing_table: table}) do
    updated_table = RoutingTable.refresh_node(table, node)

    {:noreply, %{routing_table: updated_table}}
  end

  def handle_cast({:handle_pong, pong}, %{routing_table: table}) do
    updated_table = RoutingTable.handle_pong(table, pong)

    {:noreply, %{routing_table: updated_table}}
  end

  def handle_cast({:handle_ping, params}, %{routing_table: table}) do
    updated_table = RoutingTable.handle_ping(table, params)

    {:noreply, %{routing_table: updated_table}}
  end

  def handle_cast({:ping, node}, %{routing_table: table}) do
    updated_table = RoutingTable.ping(table, node)

    {:noreply, %{routing_table: updated_table}}
  end

  def handle_cast({:handle_neighbours, neighbours}, %{routing_table: table}) do
    updated_table = RoutingTable.handle_neighbours(table, neighbours)

    {:noreply, %{routing_table: updated_table}}
  end

  def handle_call(:routing_table, _from, state = %{routing_table: routing_table}) do
    {:reply, routing_table, state}
  end

  def handle_info({:discovery_round, nodes}, %{routing_table: routing_table}) do
    updated_table = Discovery.start(routing_table, nodes)

    schedule_discovery_round(updated_table.discovery_round)

    {:noreply, %{routing_table: updated_table}}
  end

  defp schedule_discovery_round(round, nodes \\ []) do
    cond do
      round == 0 ->
        Process.send_after(self(), {:discovery_round, nodes}, 1_000)

      round <= @max_discovery_rounds ->
        Process.send_after(self(), {:discovery_round, nodes}, @discovery_round_period)

      true ->
        :ok
    end
  end

  def handle_call(
        {:neighbours, find_neighbours, endpoint},
        _from,
        state = %{routing_table: routing_table}
      ) do
    neighbours = RoutingTable.neighbours(routing_table, find_neighbours, endpoint)

    {:reply, neighbours, state}
  end

  def default_process_name do
    @default_process_name
  end
end
