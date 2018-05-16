defmodule ExWire.Kademlia.Server do
  use GenServer

  @moduledoc false

  @default_process_name KademliaState

  alias ExWire.Kademlia.{RoutingTable, Node}

  def start_link(state = {%Node{}, _}, opts \\ []) do
    process_name = opts[:process_name] || @default_process_name

    GenServer.start_link(__MODULE__, state, name: process_name)
  end

  def init({current_node = %Node{}, client_pid}) do
    routing_table = RoutingTable.new(current_node, client_pid)

    {:ok, %{routing_table: routing_table}}
  end

  def handle_cast({:refresh_node, node}, %{routing_table: table}) do
    updated_table = RoutingTable.refresh_node(table, node)

    {:noreply, %{routing_table: updated_table}}
  end

  def handle_call(:routing_table, _from, state = %{routing_table: routing_table}) do
    {:reply, routing_table, state}
  end

  def handle_call({:neighbours, node}, _from, state = %{routing_table: routing_table}) do
    neighbours = routing_table |> RoutingTable.neighbours(node)

    {:reply, neighbours, state}
  end

  def default_process_name do
    @default_process_name
  end
end
