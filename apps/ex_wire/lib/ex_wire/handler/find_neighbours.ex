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

  @spec handle(Params.t(), Keyword.t()) :: Handler.handler_response()
  def handle(server \\ Server.default_process_name(), params) do
    neighbours = fetch_neighbours(params, options)

    %Neighbours{
      nodes: neighbours,
      timestamp: params.timestamp
    }
  end

  @doc """
  Gets the list of neighbors from the Kademlina running gen server.
  """
  @spec fetch_neighbours(Params.t(), Keyword.t()) :: [Neighbour.t()]
  def fetch_neighbours(params, options) do
    params.data
    |> FindNeighbours.decode()
    |> Kademlia.neighbours(params.remote_host, process_name: options[:kademlia_process_name])
    |> nodes_to_neighbours
  end

  @spec nodes_to_neighbours([Node.t()]) :: [Neighbour.t()]
  defp nodes_to_neighbours(nodes) do
    nodes
    |> Enum.map(fn node ->
      %Neighbour{endpoint: node.endpoint, node: node.public_key}
    end)
  end
end
