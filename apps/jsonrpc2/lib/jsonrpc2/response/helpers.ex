defmodule JSONRPC2.Response.Helpers do
  @moduledoc """
  Encodes an usigned integer as a binary as described in Ethereum JSON RPC spec.
  """
  @spec encode_quantity(nil | binary() | non_neg_integer()) :: nil | <<_::24>>
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

  @spec decode_hex(String.t()) :: {:ok, binary()} | {:error, :invalid_params}
  def decode_hex("0x" <> bin), do: decode_hex(bin)

  def decode_hex(bin) do
    case Base.decode16(bin, case: :mixed) do
      :error -> {:error, :invalid_params}
      {:ok, result} -> {:ok, result}
    end
  end

  @spec decode_unsigned(String.t()) :: {:ok, non_neg_integer()} | {:error, :invalid_params}
  def decode_unsigned(binary) do
    with {:ok, binary} <- decode_hex(binary) do
      try do
        {:ok, :binary.decode_unsigned(binary)}
      rescue
        _ -> {:error, :invalid_params}
      end
    end
  end
end
