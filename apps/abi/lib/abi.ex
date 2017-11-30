defmodule ABI do
  @moduledoc """
  Documentation for ABI, the function interface language for Solidity.
  Generally, the ABI describes how to take binary Ethereum and transform
  it to or from types that Solidity understands.
  """

  @doc """
  Encodes the given data into the function signature.

  ## Examples

      iex> ABI.encode("baz(uint,address)", [50, <<1::160>> |> :binary.decode_unsigned])
      ...> |> Base.encode16(case: :lower)
      "a291add600000000000000000000000000000000000000000000000000000000000000320000000000000000000000000000000000000000000000000000000000000001"

      iex> ABI.encode("baz(uint8)", [9999])
      ** (RuntimeError) Data overflow encoding uint, data `9999` cannot fit in 8 bits
  """
  def encode(function_signature, data) do
    ABI.TypeEncoder.encode(
      data,
      ABI.FunctionSelector.decode(function_signature)
    )
  end

  @doc """
  Decodes the given data based on the function signature.

  ## Examples

      iex> ABI.decode("baz(uint,address)", "000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000320000000000000000000000000000000000000000000000000000000000000001" |> Base.decode16!(case: :lower))
      [50, <<1::160>>]
  """
  def decode(function_signature, data) do
    ABI.TypeDecoder.decode(
      data,
      ABI.FunctionSelector.decode(function_signature)
    )
  end

end
