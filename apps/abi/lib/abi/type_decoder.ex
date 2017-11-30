defmodule ABI.TypeDecoder do
  @moduledoc """
  `ABI.TypeDecoder` is responsible for decoding types to the format
  expected by Solidity. We generally take a function selector and binary
  data and decode that into the original arguments according to the
  specification.
  """

  @doc """
  Decodes the given data based on the function selector.

  Note, we don't currently try to guess the function name?

  ## Examples

      iex> "00000000000000000000000000000000000000000000000000000000000000450000000000000000000000000000000000000000000000000000000000000001"
      ...> |> Base.decode16!(case: :lower)
      ...> |> ABI.TypeDecoder.decode(
      ...>      %ABI.FunctionSelector{
      ...>        function: "baz",
      ...>        types: [
      ...>          {:uint, 32},
      ...>          :bool
      ...>        ],
      ...>        returns: :bool
      ...>      }
      ...>    )
      [69, true]

      iex> "0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b00000000000000000000000000000000000000000068656c6c6f20776f726c64"
      ...> |> Base.decode16!(case: :lower)
      ...> |> ABI.TypeDecoder.decode(
      ...>      %ABI.FunctionSelector{
      ...>        function: "baz",
      ...>        types: [
      ...>          :string
      ...>        ]
      ...>      }
      ...>    )
      ["hello world"]
  """
  def decode(encoded_data, function_selector) do
    do_decode(function_selector.types, encoded_data)
  end

  @spec do_decode([ABI.FunctionSelector.type], binary()) :: [any()]
  defp do_decode([], bin) when byte_size(bin) > 0, do: raise("Found extra binary data: #{inspect bin}")
  defp do_decode([], _), do: []
  defp do_decode([type|remaining_types], data) do
    {decoded, remaining_data} = decode_type(type, data)

    [decoded | do_decode(remaining_types, remaining_data)]
  end

  @spec decode_type(ABI.FunctionSelector.type, binary()) :: {any(), binary()}
  defp decode_type({:uint, size}, data) do
    decode_uint(data, size)
  end

  defp decode_type(:address, data), do: decode_bytes(data, 20)

  defp decode_type(:bool, data) do
    {encoded_value, rest} = decode_uint(data, 8)

    value = case encoded_value do
      1 -> true
      0 -> false
    end

    {value, rest}
  end

  defp decode_type(:string, data) do
    {string_size, rest} = decode_uint(data, 256)
    decode_bytes(rest, string_size)
  end

  defp decode_type(:bytes, data) do
    {byte_size, rest} = decode_uint(data, 256)
    decode_bytes(rest, byte_size)
  end

  defp decode_type(els, _) do
    raise "Unsupported decoding type: #{inspect els}"
  end

  @spec decode_uint(binary(), integer()) :: {integer(), binary()}
  defp decode_uint(data, size) do
    # TODO: Create `left_pad` repo, err, add to `ExthCrypto.Math`
    total_size = size + ExthCrypto.Math.mod(32 - size, 32)
    bit_size = total_size * 8

    <<value::integer-size(bit_size), rest::binary>> = data

    {value, rest}
  end

  @spec decode_bytes(binary(), integer()) :: {binary(), binary()}
  def decode_bytes(data, size) do
    # TODO: Create `unleft_pad` repo, err, add to `ExthCrypto.Math`
    total_size = size + ExthCrypto.Math.mod(32 - size, 32)
    padding_size = total_size - size

    <<_padding::binary-size(padding_size), value::binary-size(size), rest::binary()>> = data

    {value, rest}
  end

end