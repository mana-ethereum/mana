defmodule ExWire.Struct.Neighbour do
  @moduledoc """
  Struct to represent an neighbour in RLPx.
  """

  alias ExWire.Struct.Endpoint

  defstruct endpoint: nil,
            node: nil

  @type t :: %__MODULE__{
          endpoint: ExWire.Struct.Endpoint.t(),
          node: ExWire.node_id()
        }

  @doc """
  Returns a struct given an `ip` in binary form, plus an
  `udp_port` or `tcp_port`, along with a `node_id`, returns
  a `Neighbour` struct.

  ## Examples

      iex> ExWire.Struct.Neighbour.decode([<<1,2,3,4>>, <<>>, <<5>>, <<7, 7>>])
      %ExWire.Struct.Neighbour{
        endpoint: %ExWire.Struct.Endpoint{
          ip: [1,2,3,4],
          udp_port: nil,
          tcp_port: 5,
        },
        node: <<7, 7>>
      }
  """
  @spec decode(ExRLP.t()) :: t
  def decode([ip, udp_port, tcp_port, node_id]) do
    %__MODULE__{
      endpoint: Endpoint.decode([ip, udp_port, tcp_port]),
      node: node_id
    }
  end

  @doc """
  Versus `encode/4`, and given a module with an ip, a tcp_port, a udp_port,
  and a node_id, returns a tuple of encoded values.

  ## Examples

      iex> ExWire.Struct.Neighbour.encode(
      ...>   %ExWire.Struct.Neighbour{
      ...>     endpoint: %ExWire.Struct.Endpoint{
      ...>       ip: [1, 2, 3, 4],
      ...>       udp_port: nil,
      ...>       tcp_port: 5,
      ...>     },
      ...>     node: <<7, 8>>,
      ...>   }
      ...> )
      [<<1, 2, 3, 4>>, <<>>, <<0, 5>>, <<7, 8>>]
  """
  @spec encode(t) :: ExRLP.t()
  def encode(%__MODULE__{endpoint: endpoint, node: node_id}) do
    Endpoint.encode(endpoint) ++ [node_id]
  end
end
