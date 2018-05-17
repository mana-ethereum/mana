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
      <<104, 61, 189, 241, 64, 191, 8, 245, 109, 115, 6, 97, 59, 110, 31, 152, 252,
        162, 30, 138, 113, 255, 207, 36, 58, 151, 75, 222, 78, 137, 173, 70, 175,
        219, 61, 45, 146, 70, 181, 105, 123, 166, 37, 216, 218, 140, 54, 18, 169, 21,
        90, 15, 243, 105, 2, 101, 154, 148, 117, 74, 182, 40, 112, 46, 84, 245, 102,
        67, 159, 38, 71, 218, 230, 40, 55, 83, 200, 180, 236, 192, 53, 50, 235, 198,
        152, 152, 127, 241, 82, 7, 92, 202, 59, 197, 237, 102, 1, 1, 214, 1, 201,
        132, 1, 2, 3, 4, 128, 130, 0, 5, 201, 132, 5, 6, 7, 8, 130, 0, 6, 128, 4>>
  """
  @spec encode(Message.t(), Crypto.private_key()) :: binary()
  def encode(message, private_key) do
    signed_message = sign_message(message, private_key)

    Crypto.hash(signed_message) <> signed_message
  end

  @doc """
  Returns a signed version of a message. This encodes
  the message type, the encoded message itself, and a signature
  for the message.

  ## Examples

      iex> message = %ExWire.Message.Ping{
      ...>   version: 1,
      ...>   from: %ExWire.Struct.Endpoint{ip: [1, 2, 3, 4], tcp_port: 5, udp_port: nil},
      ...>   to: %ExWire.Struct.Endpoint{ip: [5, 6, 7, 8], tcp_port: nil, udp_port: 6},
      ...>   timestamp: 4
      ...> }
      iex> signature = ExWire.Protocol.sign_message(message, ExthCrypto.Test.private_key())
      iex> ExthCrypto.Signature.verify(message |> ExWire.Message.encode |> ExWire.Crypto.hash, signature, ExthCrypto.Test.public_key())
      true
  """
  @spec sign_message(Message.t(), Crypto.private_key()) :: binary()
  def sign_message(message, private_key) do
    message
    |> Message.encode()
    |> sign_binary(private_key)
  end

  @doc """
  Given a binary, returns an signed version encoded into a
  binary with signature, recovery id and the message itself.

  ## Examples

      iex> signature = ExWire.Protocol.sign_binary("mace windu", ExthCrypto.Test.private_key())
      iex> ExthCrypto.Signature.verify(ExWire.Crypto.hash("mace windu"), signature, ExthCrypto.Test.public_key())
      true
  """
  @spec sign_binary(binary(), Crypto.private_key()) :: binary()
  def sign_binary(value, private_key) do
    hashed_value = Crypto.hash(value)

    {signature, _r, _s, recovery_id} = ExthCrypto.Signature.sign_digest(hashed_value, private_key)

    signature <> <<recovery_id>> <> value
  end

  @doc """
  Returns mdc (hash of signed_message) of encoded message.

  ## Examples

      iex> message = <<237, 29, 189, 16, 55, 49, 91, 151, 78, 234, 77, 196, 228, 33, 158, 48, 254,
      ...>   206, 167, 122, 154, 30, 84, 104, 71, 143, 58, 81, 64, 76, 246, 79, 121, 172,
      ...>   184, 160, 58, 90, 92, 96, 90, 238, 168, 181, 121, 50, 213, 131, 209, 241, 51,
      ...>   1, 178, 16, 33, 254, 66, 109, 222, 74, 116, 215, 55, 114, 9, 11, 231, 55,
      ...>   220, 150, 231, 233, 223, 118, 87, 172, 141, 143, 96, 93, 229, 171, 86, 204,
      ...>   22, 3, 56, 0, 45, 122, 141, 213, 246, 179, 139, 241, 1, 2, 204, 201, 132, 1,
      ...>   2, 3, 4, 128, 130, 0, 5, 2, 3>>
      iex> ExWire.Protocol.message_mdc(message)
      <<237, 29, 189, 16, 55, 49, 91, 151, 78, 234, 77, 196, 228, 33, 158,
         48, 254, 206, 167, 122, 154, 30, 84, 104, 71, 143, 58, 81, 64, 76,
         246, 79>>
  """
  @spec message_mdc(binary()) :: binary()
  def message_mdc(<<mdc::binary-size(32), _tail::binary>>), do: mdc
end
