defmodule ExWire.Protocol do
  @moduledoc """
  Functions to handle encoding and decoding messages for
  over the wire transfer.
  """

  alias ExWire.Crypto
  alias ExWire.Message

  @doc """
  Encodes a given message by appending it to a hash of
  its contents.

  ## Examples

      iex> message = %ExWire.Message.Ping{
      ...>   version: 1,
      ...>   from: %ExWire.Struct.Endpoint{ip: [1, 2, 3, 4], tcp_port: 5, udp_port: nil},
      ...>   to: %ExWire.Struct.Endpoint{ip: [5, 6, 7, 8], tcp_port: nil, udp_port: 6},
      ...>   timestamp: 4
      ...> }
      iex> ExWire.Protocol.encode(message, <<1::256>>)
      <<223, 203, 87, 224, 25, 113, 71, 207, 167, 101, 163, 159, 125, 164, 242, 106,
        174, 114, 27, 244, 166, 149, 199, 235, 168, 37, 200, 85, 99, 36, 153, 207,
        179, 125, 146, 57, 164, 144, 42, 228, 93, 201, 118, 55, 180, 101, 253, 149,
        73, 105, 124, 110, 246, 224, 89, 76, 95, 1, 176, 14, 177, 158, 226, 102, 27,
        113, 112, 22, 21, 187, 138, 86, 7, 24, 86, 30, 104, 67, 6, 173, 90, 230, 249,
        157, 209, 74, 16, 166, 93, 187, 65, 176, 225, 90, 150, 8, 1, 1, 210, 1, 199,
        132, 1, 2, 3, 4, 128, 5, 199, 132, 5, 6, 7, 8, 6, 128, 4>>
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

      iex> ExWire.Protocol.sign_message(
      ...>   %ExWire.Message.Ping{
      ...>     version: 1,
      ...>     from: %ExWire.Struct.Endpoint{ip: [1, 2, 3, 4], tcp_port: 5, udp_port: nil},
      ...>     to: %ExWire.Struct.Endpoint{ip: [5, 6, 7, 8], tcp_port: nil, udp_port: 6},
      ...>     timestamp: 4
      ...>   },
      ...>   <<1::256>>)
      <<179, 125, 146, 57, 164, 144, 42, 228, 93, 201, 118, 55, 180, 101, 253, 149,
        73, 105, 124, 110, 246, 224, 89, 76, 95, 1, 176, 14, 177, 158, 226, 102, 27,
        113, 112, 22, 21, 187, 138, 86, 7, 24, 86, 30, 104, 67, 6, 173, 90, 230, 249,
        157, 209, 74, 16, 166, 93, 187, 65, 176, 225, 90, 150, 8, 1, 1, 210, 1, 199,
        132, 1, 2, 3, 4, 128, 5, 199, 132, 5, 6, 7, 8, 6, 128, 4>>
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

      iex> ExWire.Protocol.sign_binary(<<1>>, <<2>>)
      <<188, 63, 180, 118, 177, 27, 247, 180, 122, 195, 131, 139, 0, 109, 59, 101, 15,
        146, 86, 1, 173, 199, 202, 115, 102, 207, 188, 53, 193, 131, 98, 70, 85, 59,
        169, 36, 18, 140, 125, 33, 217, 187, 216, 117, 254, 79, 253, 133, 9, 247, 96,
        90, 203, 194, 200, 194, 34, 104, 98, 123, 148, 30, 116, 233, 0, 1>>
  """
  @spec sign_binary(binary(), Crypto.private_key) :: binary()
  def sign_binary(value, private_key) do
    hashed_value = Crypto.hash(value)

    {:ok, signature, recovery_id} = Crypto.sign(hashed_value, private_key)

    signature <> <<recovery_id>> <> value
  end

end