defmodule ExDevp2p.Message do
  @moduledoc """
  Defines a behavior for messages so that they can be
  easily encoded and decoded.
  """

  @type t :: module()
  @type message_id :: integer()

  @callback message_id() :: message_id
  @callback encode(t) :: binary()

  @doc """
  Encoded a message by concatting its `message_id` to
  the encoded data of the message itself.

  ## Examples

      iex> ExDevp2p.Message.encode(%ExDevp2p.Messages.Ping{version: 1, from: <<2>>, to: <<3>>, timestamp: 4})
      <<>>

       iex> ExDevp2p.Message.encode(%ExDevp2p.Messages.Pong{to: <<1>>, hash: <<2>>, timestamp: 3})
      <<>>
  """
  @spec encode(t) :: binary()
  def encode(message) do
    <<message.__struct__.message_id()>> <> message.__struct__.encode(message)
  end

end