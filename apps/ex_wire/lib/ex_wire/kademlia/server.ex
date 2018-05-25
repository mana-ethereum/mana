defmodule ExWire.Kademlia.Server do
  use GenServer

  @moduledoc false

  @default_process_name KademliaState

  alias ExWire.Kademlia.{RoutingTable, Node}

  def start_link(params) do
    name = params[:name] || @default_process_name
    network_client_name = Keyword.fetch!(params, :network_client_name)
    current_node = Keyword.fetch!(params, :current_node)

    GenServer.start_link(__MODULE__, {current_node, network_client_name}, name: name)
  end

  def init({current_node = %Node{}, network_client_name}) do
    routing_table = RoutingTable.new(current_node, network_client_name)

    {:ok, %{routing_table: routing_table}}
  end

  def handle_cast({:refresh_node, node}, %{routing_table: table}) do
    updated_table = RoutingTable.refresh_node(table, node)

    {:noreply, %{routing_table: updated_table}}
  end

  def handle_cast({:handle_pong, pong, params}, %{routing_table: table}) do
    updated_table = RoutingTable.handle_pong(table, pong, params)

    {:noreply, %{routing_table: updated_table}}
  end

  def handle_cast({:handle_ping, params}, %{routing_table: table}) do
    updated_table = RoutingTable.handle_ping(table, params)

    {:noreply, %{routing_table: updated_table}}
  end

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

  def default_process_name do
    @default_process_name
  end
end
