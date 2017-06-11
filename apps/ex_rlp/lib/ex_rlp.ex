defmodule ExRLP do
  alias ExRLP.Encoder
  alias ExRLP.Decoder

  def encode(item) do
    item |> Encoder.encode
  end

  def decode(item, type \\ :binary) do
    item |> Decoder.decode(type)
  end
end
