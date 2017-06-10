defmodule ExRLP do
  alias ExRLP.Encoder

  def encode(item) do
    item |> Encoder.encode
  end
end
