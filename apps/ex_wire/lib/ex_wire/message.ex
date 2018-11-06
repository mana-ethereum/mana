defmodule ExWire.Message do
  @moduledoc """
  Defines a behavior for messages so that they can be easily encoded and
  decoded for transfer from and to the wire.
  """

  alias ExWire.Crypto
  alias ExWire.Message.{FindNeighbours, Neighbours, Ping, Pong}
  alias ExWire.Struct.Endpoint

  defmodule UnknownMessageError do
    defexception [:message]
  end

  @type t :: Ping.t() | Pong.t() | FindNeighbours.t() | Neighbours.t()
  @type message_id :: integer()

  @callback message_id() :: message_id
  @callback encode(t) :: binary()
  @callback to(t) :: Endpoint.t() | nil

  @message_types %{
    0x01 => Ping,
    0x02 => Pong,
    0x03 => FindNeighbours,
    0x04 => Neighbours
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

  @doc """
  Recovers public key from message.

  ## Examples

      iex> pong = %ExWire.Message.Pong{
      ...>  hash: <<186, 68, 151, 218, 158, 6, 56, 106, 29, 48, 177, 35, 29, 4, 114, 189,
      ...>  50, 66, 82, 184, 158, 70, 161, 192, 157, 133, 159, 214, 98, 85, 140, 136>>,
      ...>  timestamp: 1526987786,
      ...>  to: %ExWire.Struct.Endpoint{
      ...>    ip: [52, 176, 100, 77],
      ...>    tcp_port: nil,
      ...>    udp_port: 30303
      ...>  }
      ...> }
      iex> signature = <<193, 30, 149, 122, 226, 192, 230, 158, 118, 204, 173, 80, 63,
      ...>   232, 67, 152, 216, 249, 89, 52, 162, 92, 233, 201, 177, 108, 63, 120, 152,
      ...>   134, 149, 220, 73, 198, 29, 93, 218, 123, 50, 70, 8, 202, 17, 171, 67, 245,
      ...>   70, 235, 163, 158, 201, 246, 223, 114, 168, 7, 7, 95, 9, 53, 165, 8, 177,
      ...>   13>>
      iex> ExWire.Message.recover_public_key(pong, signature, 1)
      <<4, 134, 90, 99, 37, 91, 59, 182, 128, 35, 182, 191, 253, 80, 149, 17, 143, 204,
      19, 231, 157, 207, 1, 79, 228, 228, 126, 6, 92, 53, 12, 124, 199, 42, 242,
      229, 62, 255, 137, 95, 17, 186, 27, 187, 106, 43, 51, 39, 28, 17, 22, 238,
      135, 15, 38, 102, 24, 234, 223, 194, 231, 138, 167, 52, 156>>
  """
  @spec recover_public_key(t() | binary(), binary(), integer()) :: binary()
  def recover_public_key(message, signature, recovery_id) when is_binary(message) do
    message
    |> Crypto.hash()
    |> Crypto.recover_public_key(signature, recovery_id)
  end

  def recover_public_key(message, signature, recovery_id) do
    message
    |> encode()
    |> recover_public_key(signature, recovery_id)
  end
end
