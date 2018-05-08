defmodule ExWire.Kademlia do
  use GenServer

  @moduledoc """
  Handles Kademlia algorithm state.
  """

  alias ExWire.Struct.{Peer, RoutingTable}

  def start_link(current_node = %Peer{}) do
    GenServer.start_link(__MODULE__, current_node, name: ExWire.Kademlia)
  end

  def init(current_node = %Peer{}) do
    routing_table = current_node |> RoutingTable.new()

    {:ok, %{routing_table: routing_table}}
  end
end
