defmodule ExWire.Message.Ping do
  @moduledoc """
  A wrapper for ExWire's `Ping` message.
  """

  alias ExWire.Struct.Endpoint

  @behaviour ExWire.Message
  @message_id 0x01

  defstruct version: nil,
            from: nil,
            to: nil,
            timestamp: nil

  @type t :: %__MODULE__{
          version: integer(),
          from: Endpoint.t(),
          to: Endpoint.t(),
          timestamp: integer()
        }

  @spec message_id() :: ExWire.Message.message_id()
  def message_id, do: @message_id

  @doc """
  Decodes a given message binary, which is assumed
  to be an RLP encoded list of elements.

  ## Examples

      iex> ExWire.Message.Ping.decode([1, [<<1,2,3,4>>, <<>>, <<5>>], [<<5,6,7,8>>, <<6>>, <<>>], 4] |> ExRLP.encode)
      %ExWire.Message.Ping{
        version: 1,
        from: %ExWire.Struct.Endpoint{ip: [1, 2, 3, 4], tcp_port: 5, udp_port: nil},
        to: %ExWire.Struct.Endpoint{ip: [5, 6, 7, 8], tcp_port: nil, udp_port: 6},
        timestamp: 4,
      }

      iex> ExWire.Message.Ping.decode([<<1>>] |> ExRLP.encode)
      ** (MatchError) no match of right hand side value: [<<1>>]
  """
  @spec decode(binary()) :: t
  def decode(data) do
    [version, from, to, timestamp] = ExRLP.decode(data)

    %__MODULE__{
      version: :binary.decode_unsigned(version),
      from: Endpoint.decode(from),
      to: Endpoint.decode(to),
      timestamp: :binary.decode_unsigned(timestamp)
    }
  end

  @doc """
  Given a Ping message, encodes it so it can be sent on the wire in RLPx.

  ## Examples

      iex> ExWire.Message.Ping.encode(%ExWire.Message.Ping{
      ...>   version: 1,
      ...>   from: %ExWire.Struct.Endpoint{ip: [1, 2, 3, 4], tcp_port: 5, udp_port: nil},
      ...>   to: %ExWire.Struct.Endpoint{ip: [5, 6, 7, 8], tcp_port: nil, udp_port: 6},
      ...>   timestamp: 4}
      ...> ) |> ExRLP.decode()
      [<<1>>, [<<1, 2, 3, 4>>, "", <<0, 5>>], [<<5, 6, 7, 8>>, <<0, 6>>, ""], <<4>>]
  """
  @spec encode(t) :: binary()
  def encode(%__MODULE__{version: version, from: from, to: to, timestamp: timestamp}) do
    ExRLP.encode([
      version,
      Endpoint.encode(from),
      Endpoint.encode(to),
      timestamp
    ])
  end

  @doc """
  Ping messages specify a destination.

  ## Examples

      iex> ExWire.Message.Ping.to(%ExWire.Message.Ping{
      ...>   version: 1,
      ...>   from: %ExWire.Struct.Endpoint{ip: [1, 2, 3, 4], tcp_port: 5, udp_port: nil},
      ...>   to: %ExWire.Struct.Endpoint{ip: [5, 6, 7, 8], tcp_port: nil, udp_port: 6},
      ...>   timestamp: 4}
      ...> )
      %ExWire.Struct.Endpoint{ip: [5, 6, 7, 8], tcp_port: nil, udp_port: 6}
  """
  @spec to(t) :: Endpoint.t() | nil
  def to(message) do
    message.to
  end
end
