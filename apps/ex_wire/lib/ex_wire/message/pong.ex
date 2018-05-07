defmodule ExWire.Message.Pong do
  @moduledoc """
  A wrapper for ExWire's `Pong` message.
  """

  alias ExWire.Struct.Endpoint

  @message_id 0x02

  defstruct to: nil,
            hash: nil,
            timestamp: nil

  @type t :: %__MODULE__{
          to: Endpoint.t(),
          hash: binary(),
          timestamp: integer()
        }

  @spec message_id() :: ExWire.Message.message_id()
  def message_id, do: @message_id

  @doc """
  Decodes a given message binary, which is assumed
  to be an RLP encoded list of elements.

  ## Examples

      iex> ExWire.Message.Pong.decode([[<<1,2,3,4>>, <<>>, <<0, 5>>], <<2>>, 3] |> ExRLP.encode)
      %ExWire.Message.Pong{
        to: %ExWire.Struct.Endpoint{ip: [1, 2, 3, 4], tcp_port: 5, udp_port: nil},
        hash: <<2>>,
        timestamp: 3,
      }

      iex> ExWire.Message.Pong.decode([<<1>>] |> ExRLP.encode)
      ** (MatchError) no match of right hand side value: [<<1>>]
  """
  @spec decode(binary()) :: t
  def decode(data) do
    [to, hash, timestamp] = ExRLP.decode(data)

    %__MODULE__{
      to: Endpoint.decode(to),
      hash: hash,
      timestamp: :binary.decode_unsigned(timestamp)
    }
  end

  @doc """
  Given a Pong message, encodes it so it can be sent on the wire in RLPx.

  ## Examples

      iex> ExWire.Message.Pong.encode(%ExWire.Message.Pong{
      ...>   to: %ExWire.Struct.Endpoint{ip: [1, 2, 3, 4], tcp_port: 5, udp_port: nil},
      ...>   hash: <<2>>,
      ...>   timestamp: 3}
      ...> ) |> ExRLP.decode()
      [[<<1, 2, 3, 4>>, "", <<0, 5>>], <<2>>, <<3>>]
  """
  @spec encode(t) :: binary()
  def encode(%__MODULE__{to: to, hash: hash, timestamp: timestamp}) do
    ExRLP.encode([
      Endpoint.encode(to),
      hash,
      timestamp
    ])
  end

  @doc """
  Pong messages should be routed to given endpoint.

  ## Examples

      iex> ExWire.Message.Pong.to(%ExWire.Message.Pong{
      ...>   to: %ExWire.Struct.Endpoint{ip: [1, 2, 3, 4], tcp_port: 5, udp_port: nil},
      ...>   hash: <<2>>,
      ...>   timestamp: 3}
      ...> )
      %ExWire.Struct.Endpoint{ip: [1, 2, 3, 4], tcp_port: 5, udp_port: nil}
  """
  @spec to(t) :: Endpoint.t() | nil
  def to(message) do
    message.to
  end
end
