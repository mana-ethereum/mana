defmodule ExWire.Message.Neighbours do
  @moduledoc """
  A wrapper for ExWire's `Neighbours` message.
  """

  alias ExWire.Struct.Neighbour

  @behaviour ExWire.Message
  @message_id 0x04

  defstruct nodes: [],
            timestamp: []

  @type t :: %__MODULE__{
          nodes: [Neighbour.t()],
          timestamp: integer()
        }

  @spec message_id() :: ExWire.Message.message_id()
  def message_id, do: @message_id

  @doc """
  Decodes a given message binary, which is assumed
  to be an RLP encoded list of elements.

  ## Examples

      iex> ExWire.Message.Neighbours.decode([
      ...>   [],
      ...>   2
      ...> ] |> ExRLP.encode)
      %ExWire.Message.Neighbours{
        nodes: [],
        timestamp: 2,
      }

      iex> ExWire.Message.Neighbours.decode([
      ...>   [[<<1,2,3,4>>, <<>>, <<5>>, <<7, 7>>]],
      ...>   2
      ...> ] |> ExRLP.encode)
      %ExWire.Message.Neighbours{
        nodes: [%ExWire.Struct.Neighbour{endpoint: %ExWire.Struct.Endpoint{ip: [1,
                2, 3, 4], tcp_port: 5, udp_port: nil}, node: <<7, 7>>}],
        timestamp: 2,
      }

      iex> ExWire.Message.Neighbours.decode([
      ...>   [[<<1,2,3,4>>, <<>>, <<5>>, <<7, 7>>], [<<5,6,7,8>>, <<6>>, <<>>, <<8, 8>>]],
      ...>   2
      ...> ] |> ExRLP.encode)
      %ExWire.Message.Neighbours{
        nodes: [
          %ExWire.Struct.Neighbour{endpoint: %ExWire.Struct.Endpoint{ip: [1, 2, 3, 4], tcp_port: 5, udp_port: nil}, node: <<7, 7>>},
          %ExWire.Struct.Neighbour{endpoint: %ExWire.Struct.Endpoint{ip: [5, 6, 7, 8], tcp_port: nil, udp_port: 6}, node: <<8, 8>>}
        ],
        timestamp: 2,
      }

      iex> ExWire.Message.Neighbours.decode([1] |> ExRLP.encode)
      ** (MatchError) no match of right hand side value: [<<1>>]
  """
  @spec decode(binary()) :: t
  def decode(data) do
    [encoded_nodes, timestamp] = ExRLP.decode(data)

    %__MODULE__{
      nodes: Enum.map(encoded_nodes, &Neighbour.decode/1),
      timestamp: :binary.decode_unsigned(timestamp)
    }
  end

  @doc """
  Given a Neighbours message, encodes it so it can be sent on the wire in RLPx.

  ## Examples

      iex> ExWire.Message.Neighbours.encode(%ExWire.Message.Neighbours{nodes: [], timestamp: 1})
      ...> |> ExRLP.decode()
      [[], <<1>>]

      iex> ExWire.Message.Neighbours.encode(%ExWire.Message.Neighbours{nodes: [
      ...>   %ExWire.Struct.Neighbour{endpoint: %ExWire.Struct.Endpoint{ip: [1, 2, 3, 4], tcp_port: 5, udp_port: nil}, node: <<7, 7>>},
      ...>   %ExWire.Struct.Neighbour{endpoint: %ExWire.Struct.Endpoint{ip: [5, 6, 7, 8], tcp_port: nil, udp_port: 6}, node: <<8, 8>>}],
      ...>   timestamp: 1})
      ...> |> ExRLP.decode()
      [[[<<1,2,3,4>>, <<>>, <<0, 5>>, <<7, 7>>], [<<5,6,7,8>>, <<0, 6>>, <<>>, <<8, 8>>]], <<1>>]
  """
  @spec encode(t) :: binary()
  def encode(%__MODULE__{nodes: nodes, timestamp: timestamp}) do
    ExRLP.encode([
      Enum.map(nodes, &Neighbour.encode/1),
      timestamp
    ])
  end

  @doc """
  Neighbours messages do not specify a destination.

  ## Examples

      iex> ExWire.Message.Neighbours.to(%ExWire.Message.Neighbours{nodes: [], timestamp: 1})
      nil
  """
  @spec to(t) :: ExWire.Struct.Endpoint.t() | nil
  def to(_message), do: nil
end
