defmodule ExRLP do
  alias ExRLP.{Encoder, Decoder}

  @moduledoc File.read!("#{__DIR__}/../README.md")

  def encode(item, options \\ nil) do
    item |> Encoder.encode(options)
  end

  def decode(item, type \\ :binary, options \\ nil) do
    item |> Decoder.decode(type, options)
  end
end
