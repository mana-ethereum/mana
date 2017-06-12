defmodule ExRLP do
  alias ExRLP.Encoder
  alias ExRLP.Decoder

  @spec encode(String.t | non_neg_integer | list) :: String.t
  def encode(item) do
    item |> Encoder.encode
  end

  @spec decode(String.t) :: String.t
  @spec decode(String.t, atom) :: String.t | non_neg_integer | list
  def decode(item, type \\ :binary) do
    item |> Decoder.decode(type)
  end
end
