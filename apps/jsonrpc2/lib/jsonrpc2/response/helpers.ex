defmodule JSONRPC2.Response.Helpers do
  @moduledoc """
  Encodes an usigned integer as a binary as described in Ethereum JSON RPC spec.
  """
  @spec encode_quantity(binary() | non_neg_integer() | nil) :: binary() | nil
  def encode_quantity(binary) when is_binary(binary) do
    hex_binary = Base.encode16(binary, case: :lower)

    result = String.replace_leading(hex_binary, "0", "")

    result = if result == "", do: "0", else: result

    "0x#{result}"
  end

  def encode_quantity(value) when is_integer(value) do
    value
    |> :binary.encode_unsigned()
    |> encode_quantity()
  end

  def encode_quantity(value) when is_nil(value) do
    nil
  end

  @spec encode_unformatted_data(binary()) :: binary() | nil
  def encode_unformatted_data(binary) when is_binary(binary) do
    Exth.encode_hex(binary)
  end

  def encode_unformatted_data(binary) when is_nil(binary) do
    nil
  end
end
