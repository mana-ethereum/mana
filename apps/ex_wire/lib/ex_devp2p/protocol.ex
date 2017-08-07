defmodule ExDevp2p.Protocol do
  @moduledoc """
  Functions to handle encoding and decoding messages for
  over the wire transfer.
  """

  alias ExDevp2p.Crypto
  alias ExDevp2p.Message

  @doc """
  Encodes a given message by appending it to a hash of
  its contents.

  ## Examples

      iex> ExDevp2p.Protocol.encode("hi mom", <<1>>)
      <<2>>
  """
  @spec encode(Message.t, Crypto.private_key) :: binary()
  def encode(message, private_key) do
    signed_message = sign_message(message, private_key)

    Crypto.hash(signed_message) <> signed_message
  end

  @doc """
  Returns a signed version of a message. This encodes
  the message type, the encoded message itself, and a signature
  for the message.

  ## Examples

      iex> ExDevp2p.Protocol.sign_message(%ExDevp2p.Message.Ping{version: 1, from: <<2>>, to: <<3>>, timestamp: 4}, <<1>>)
      <<>>
  """
  @spec sign_message(Message.t, Crypto.private_key) :: binary()
  def sign_message(message, private_key) do
    message
      |> Message.encode()
      |> sign_binary(private_key)
  end

  @doc """
  Given a binary, returns an signed version encoded into a
  binary with signature, recovery id and the message itself.

  ## Examples

      iex> ExDevp2p.Protocol.sign_binary(<<1>>, <<2>>)
      <<3>>
  """
  @spec sign_binary(binary(), Crypto.private_key) :: binary()
  def sign_binary(value, private_key) do
    hashed_value = Crypto.hash(value)

    {:ok, signature, recovery_id} = Crypto.sign(hashed_value, private_key)

    signature <> <<recovery_id>> <> value
  end

end