defmodule ExRLP do
  alias ExRLP.Encoder
  alias ExRLP.Decoder

  def encode(item) do
    item |> Encoder.encode
  end

  def decode(item) do
    item |> Decoder.decode
  end
end
