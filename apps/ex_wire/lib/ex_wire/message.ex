defmodule ExWire.Message do
  @moduledoc """
  Defines a behavior for messages so that they can be
  easily encoded and decoded.
  """

  @type t :: module()
  @type message_id :: integer()

  @callback message_id() :: message_id
  @callback encode(t) :: binary()
  @callback to(t) :: ExWire.Endpoint.t | nil

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
      <<1, 210, 1, 199, 132, 1, 2, 3, 4, 128, 5, 199, 132, 5, 6, 7, 8, 6, 128, 4>>

      iex> ExWire.Message.encode(%ExWire.Message.Pong{to: %ExWire.Struct.Endpoint{ip: [5, 6, 7, 8], tcp_port: nil, udp_port: 6}, hash: <<2>>, timestamp: 3})
      <<2, 202, 199, 132, 5, 6, 7, 8, 6, 128, 2, 3>>
  """
  @spec encode(t) :: binary()
  def encode(message) do
    <<message.__struct__.message_id()>> <> message.__struct__.encode(message)
  end

end