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
      <<230, 32, 144, 232, 197, 11, 147, 44, 198, 44, 96, 204, 211, 152, 88, 205, 130,
        36, 0, 34, 171, 57, 78, 121, 99, 95, 155, 40, 207, 71, 157, 36, 178, 9, 141,
        121, 121, 118, 105, 139, 136, 85, 28, 239, 85, 113, 234, 145, 130, 16, 94,
        121, 138, 128, 96, 187, 219, 2, 220, 70, 241, 118, 197, 140, 44, 32, 211, 167,
        43, 69, 242, 65, 91, 163, 73, 230, 24, 102, 78, 0, 253, 38, 2, 11, 160, 45,
        28, 113, 29, 78, 211, 46, 229, 146, 234, 255, 1, 1, 210, 1, 199, 132, 1, 2, 3,
        4, 128, 5, 199, 132, 5, 6, 7, 8, 6, 128, 4>>
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
      <<228, 150, 232, 48, 101, 148, 30, 32, 207, 150, 50, 79, 94, 18, 68, 25, 221,
        57, 93, 215, 78, 4, 34, 242, 114, 58, 199, 195, 222, 222, 80, 109, 47, 197,
        215, 99, 33, 168, 14, 204, 132, 90, 248, 179, 73, 213, 124, 175, 50, 192, 93,
        140, 125, 221, 212, 246, 174, 164, 159, 242, 152, 205, 44, 26, 0, 1, 210, 1,
        199, 132, 1, 2, 3, 4, 128, 5, 199, 132, 5, 6, 7, 8, 6, 128, 4>>
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
      <<203, 247, 245, 237, 34, 215, 230, 204, 82, 202, 231, 172, 244, 121, 129, 156,
        135, 87, 253, 170, 61, 37, 218, 1, 244, 85, 190, 39, 234, 152, 73, 56, 38,
        124, 162, 101, 227, 162, 73, 182, 129, 42, 45, 99, 139, 49, 217, 130, 243,
        150, 122, 156, 225, 212, 73, 16, 161, 228, 251, 92, 105, 87, 114, 92, 0, 1>>
  """
  @spec sign_binary(binary(), Crypto.private_key) :: binary()
  def sign_binary(value, private_key) do
    hashed_value = Crypto.hash(value)

    {:ok, signature, recovery_id} = Crypto.sign(hashed_value, private_key)

    signature <> <<recovery_id>> <> value
  end

end