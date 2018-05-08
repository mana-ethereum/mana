defmodule ExWire.Message do
  @moduledoc """
  Defines a behavior for messages so that they can be
  easily encoded and decoded.
  """

  defmodule UnknownMessageError do
    defexception [:message]
  end

  @type t :: module()
  @type message_id :: integer()

  @callback message_id() :: message_id
  @callback encode(t) :: binary()
  @callback to(t) :: ExWire.Endpoint.t() | nil

  @message_types %{
    0x01 => ExWire.Message.Ping,
    0x02 => ExWire.Message.Pong,
    0x03 => ExWire.Message.FindNeighbours,
    0x04 => ExWire.Message.Neighbours
  }

  @doc """
  Decodes a message of given `type` based on the encoded
  data. Effectively reverses the `decode/1` function.

  ## Examples

      iex> ExWire.Message.decode(0x01, <<210, 1, 199, 132, 1, 2, 3, 4, 128, 5, 199, 132, 5, 6, 7, 8, 6, 128, 4>>)
      %ExWire.Message.Ping{
        version: 1,
        from: %ExWire.Struct.Endpoint{ip: [1, 2, 3, 4], tcp_port: 5, udp_port: nil},
        to: %ExWire.Struct.Endpoint{ip: [5, 6, 7, 8], tcp_port: nil, udp_port: 6},
        timestamp: 4
      }

      iex> ExWire.Message.decode(0x02, <<202, 199, 132, 5, 6, 7, 8, 6, 128, 2, 3>>)
      %ExWire.Message.Pong{
      to: %ExWire.Struct.Endpoint{ip: [5, 6, 7, 8], tcp_port: nil, udp_port: 6}, hash: <<2>>, timestamp: 3
      }

      iex> ExWire.Message.decode(0x99, <<>>)
      ** (ExWire.Message.UnknownMessageError) Unknown message type: 0x99
  """
  @spec decode(integer(), binary()) :: t
  def decode(type, data) do
    case @message_types[type] do
      nil -> raise UnknownMessageError, "Unknown message type: #{inspect(type, base: :hex)}"
      mod -> mod.decode(data)
    end
  end

  @doc """
  Encoded a message by concatting its `message_id` to
  the encoded data of the message itself.

  ## Examples

      iex> ExWire.Message.encode(
      ...>   %ExWire.Message.Ping{
      ...>     version: 1,
      ...>     from: %ExWire.Struct.Endpoint{ip: [1, 2, 3, 4], tcp_port: 5, udp_port: nil},
      ...>     to: %ExWire.Struct.Endpoint{ip: [5, 6, 7, 8], tcp_port: nil, udp_port: 6},
      ...>     timestamp: 4
      ...>   }
      ...> )
      <<1, 214, 1, 201, 132, 1, 2, 3, 4, 128, 130, 0, 5, 201, 132, 5, 6, 7, 8, 130, 0, 6, 128, 4>>

      iex> ExWire.Message.encode(%ExWire.Message.Pong{to: %ExWire.Struct.Endpoint{ip: [5, 6, 7, 8], tcp_port: nil, udp_port: 6}, hash: <<2>>, timestamp: 3})
      <<2, 204, 201, 132, 5, 6, 7, 8, 130, 0, 6, 128, 2, 3>>
  """
  @spec encode(t) :: binary()
  def encode(message) do
    <<message.__struct__.message_id()>> <> message.__struct__.encode(message)
  end
end
