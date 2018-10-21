defmodule ExWire.Handler.Neighbours do
  @moduledoc """
  Module to handle a response to a Neighbours message, which
  should be to add the neighbors to the correct K-Buckets.
  """

  require Logger

  alias ExWire.Handler
  alias ExWire.Kademlia
  alias ExWire.Message.Neighbours

  @doc """
  Handler for a Neighbours message.

  ## Examples

      iex> message = %ExWire.Message.Neighbours{
      ...>   nodes: [
      ...>     %ExWire.Struct.Neighbour{endpoint: %ExWire.Struct.Endpoint{ip: [1, 2, 3, 4], tcp_port: 5, udp_port: nil}, node: <<7, 7>>},
      ...>     %ExWire.Struct.Neighbour{endpoint: %ExWire.Struct.Endpoint{ip: [5, 6, 7, 8], tcp_port: nil, udp_port: 6}, node: <<8, 8>>}],
      ...>   timestamp: 1
      ...> }
      iex> ExWire.Handler.Neighbours.handle(%ExWire.Handler.Params{
      ...>   remote_host: %ExWire.Struct.Endpoint{ip: [1,2,3,4], udp_port: 55},
      ...>   signature: 2,
      ...>   recovery_id: 3,
      ...>   hash: <<5>>,
      ...>   data: message |> ExWire.Message.Neighbours.encode(),
      ...>   timestamp: 123,
      ...> })
      :no_response
  """
  @spec handle(Handler.Params.t(), Keyword.t()) :: Handler.handler_response()
  def handle(params, options \\ []) do
    neighbours = Neighbours.decode(params.data)

    Kademlia.handle_neighbours(neighbours, process_name: options[:kademlia_process_name])

    :no_response
  end
end
