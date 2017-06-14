defmodule ExDevp2p.Protocol do
  @private_key 0xd772e3d6a001a38064dd23964dd2836239fa0e6cec8b28972a87460a17210fe9
  alias ExDevp2p.Crypto

  def sign(message) do
    message_hash = Crypto.hash(message)
    {:ok, signature, recovery_id} = Crypto.sign(message_hash, :binary.encode_unsigned(@private_key))
    signature <> :binary.encode_unsigned(recovery_id) <> message
  end

  def hash(message) do
    Crypto.hash(message) <> message
  end
end
