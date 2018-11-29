defmodule ExWire.Handler.FindNeighbours do
  @moduledoc """
  Module that handles a response to a FindNeighbours message, which generates a
  Neighbours response with the closest nodes to provided node id.
  """

  alias ExWire.{Handler, Kademlia}
  alias ExWire.Handler.Params
  alias ExWire.Kademlia.Node
  alias ExWire.Message.{FindNeighbours, Neighbours}
  alias ExWire.Struct.Neighbour

  @spec handle(GenServer.server(), Params.t()) :: Handler.handler_response()
  def handle(server \\ Kademlia.server(), params) do
    neighbours = fetch_neighbours(server, params)

    %Neighbours{
      nodes: neighbours,
      timestamp: params.timestamp
    }
  end

  @doc """
  Gets the list of neighbors from the Kademlina running gen server.
  """
  @spec fetch_neighbours(GenServer.server(), Params.t()) :: [Neighbour.t()]
  def fetch_neighbours(server \\ Kademlia.server(), params) do
    neighbours = FindNeighbours.decode(params.data)

    nodes_to_neighbours(Kademlia.neighbours(server, neighbours, params.remote_host))
  end

  @spec nodes_to_neighbours([Node.t()]) :: [Neighbour.t()]
  defp nodes_to_neighbours(nodes) do
    nodes
    |> Enum.map(fn node ->
      %Neighbour{endpoint: node.endpoint, node: node.public_key}
    end)
  end
end
