defmodule ExDevp2p.Protocol do
  @private_key 0xd772e3d6a001a38064dd23964dd2836239fa0e6cec8b28972a87460a17210fe9
  alias ExDevp2p.Crypto

  def encode(message) do
    hash(message) <>
      signed_message(message)
  end

  def hash(message) do
    Crypto.hash(signed_message(message))
  end

  def signed_message(message) do
    <<message.__struct__.id()>> <>
      message.__struct__.encode(message)
      |> sign
  end

  def sign(message) do
    message_hash = Crypto.hash(message)
    {:ok, signature, recovery_id} = Crypto.sign(message_hash, @private_key)
    signature <> <<recovery_id>> <> message
  end
end
