defmodule ExDevp2p.Encodings.Binary do
  def decode(data) do
    :binary.decode_unsigned(data)
  end

  def encode(data) do
  end
end
