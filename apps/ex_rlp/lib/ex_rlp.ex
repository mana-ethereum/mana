defmodule ExRLP do
  alias ExRLP.Encoder
  alias ExRLP.Decoder

  @spec encode(String.t | non_neg_integer | list) :: String.t
  def encode(item) do
    item |> Encoder.encode
  end

  @spec decode(String.t) :: String.t | list
  def decode(item) do
    item |> Decoder.decode
  end
end
