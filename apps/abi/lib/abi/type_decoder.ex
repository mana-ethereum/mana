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

      iex> "000000000000000000000000000000000000000000000000000000000000000b68656c6c6f20776f726c64000000000000000000000000000000000000000000"
      ...> |> Base.decode16!(case: :lower)
      ...> |> ABI.TypeDecoder.decode(
      ...>      %ABI.FunctionSelector{
      ...>        function: nil,
      ...>        types: [
      ...>          :string
      ...>        ]
      ...>      }
      ...>    )
      ["hello world"]

      iex> "00000000000000000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000000000000000001"
      ...> |> Base.decode16!(case: :lower)
      ...> |> ABI.TypeDecoder.decode(
      ...>      %ABI.FunctionSelector{
      ...>        function: nil,
      ...>        types: [
      ...>          {:tuple, [{:uint, 32}, :bool]}
      ...>        ]
      ...>      }
      ...>    )
      [{17, true}]

      iex> "00000000000000000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000000000000000001"
      ...> |> Base.decode16!(case: :lower)
      ...> |> ABI.TypeDecoder.decode(
      ...>      %ABI.FunctionSelector{
      ...>        function: nil,
      ...>        types: [
      ...>          {:array, {:uint, 32}, 2}
      ...>        ]
      ...>      }
      ...>    )
      [[17, 1]]

      iex> "000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000000000000000001"
      ...> |> Base.decode16!(case: :lower)
      ...> |> ABI.TypeDecoder.decode(
      ...>      %ABI.FunctionSelector{
      ...>        function: nil,
      ...>        types: [
      ...>          {:array, {:uint, 32}}
      ...>        ]
      ...>      }
      ...>    )
      [[17, 1]]

      iex> "000000000000000000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001"
      ...> |> Base.decode16!(case: :lower)
      ...> |> ABI.TypeDecoder.decode(
      ...>      %ABI.FunctionSelector{
      ...>        function: nil,
      ...>        types: [
      ...>          {:array, {:uint, 32}, 2},
      ...>          :bool
      ...>        ]
      ...>      }
      ...>    )
      [[17, 1], true]

      iex> "000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000007617765736f6d6500000000000000000000000000000000000000000000000000"
      ...> |> Base.decode16!(case: :lower)
      ...> |> ABI.TypeDecoder.decode(
      ...>      %ABI.FunctionSelector{
      ...>        function: nil,
      ...>        types: [
      ...>          {:tuple, [:string, :bool]}
      ...>        ]
      ...>      }
      ...>    )
      [{"awesome", true}]

      iex> "00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000"
      ...> |> Base.decode16!(case: :lower)
      ...> |> ABI.TypeDecoder.decode(
      ...>      %ABI.FunctionSelector{
      ...>        function: nil,
      ...>        types: [
      ...>          {:tuple, [{:array, :address}]}
      ...>        ]
      ...>      }
      ...>    )
      [{[]}]

      iex> "00000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000c556e617574686f72697a656400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000204a2bf2ff0a4eaf1890c8d8679eaa446fb852c4000000000000000000000000861d9af488d5fa485bb08ab6912fff4f7450849a"
      ...> |> Base.decode16!(case: :lower)
      ...> |> ABI.TypeDecoder.decode(
      ...>      %ABI.FunctionSelector{
      ...>        function: nil,
      ...>        types: [{:tuple,[
      ...>          :string,
      ...>          {:array, {:uint, 256}}
      ...>        ]}]
      ...>      }
      ...>    )
      [{
        "Unauthorized",
        [
          184341788326688649239867304918349890235378717380,
          765664983403968947098136133435535343021479462042,
        ]
      }]
  """
  def decode(encoded_data, function_selector) do
    decode_raw(encoded_data, function_selector.types)
  end

  @doc """
  Similar to `ABI.TypeDecoder.decode/2` except accepts a list of types instead
  of a function selector.

  ## Examples

      iex> "000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000007617765736f6d6500000000000000000000000000000000000000000000000000"
      ...> |> Base.decode16!(case: :lower)
      ...> |> ABI.TypeDecoder.decode_raw([{:tuple, [:string, :bool]}])
      [{"awesome", true}]
  """
  def decode_raw(encoded_data, types) do
    do_decode(types, encoded_data, [])
  end

  @spec do_decode([ABI.FunctionSelector.type], binary(), [any()]) :: [any()]
  defp do_decode([], bin, _) when byte_size(bin) > 0, do: raise("Found extra binary data: #{inspect bin}")
  defp do_decode([], _, acc), do: Enum.reverse(acc)
  defp do_decode([type|remaining_types], data, acc) do
    {decoded, remaining_data} = decode_type(type, data)

    do_decode(remaining_types, remaining_data, [decoded | acc])
  end

  @spec decode_type(ABI.FunctionSelector.type, binary()) :: {any(), binary()}
  defp decode_type({:uint, size_in_bits}, data) do
    decode_uint(data, size_in_bits)
  end

  defp decode_type(:address, data), do: decode_bytes(data, 20, :left)

  defp decode_type(:bool, data) do
    {encoded_value, rest} = decode_uint(data, 8)

    value = case encoded_value do
      1 -> true
      0 -> false
    end

    {value, rest}
  end

  defp decode_type(:string, data) do
    {string_size_in_bytes, rest} = decode_uint(data, 256)
    decode_bytes(rest, string_size_in_bytes, :right)
  end

  defp decode_type(:bytes, data) do
    {byte_size, rest} = decode_uint(data, 256)
    decode_bytes(rest, byte_size, :right)
  end

  defp decode_type({:array, type}, data) do
    {element_count, rest} = decode_uint(data, 256)
    decode_type({:array, type, element_count}, rest)
  end

  defp decode_type({:array, _type, 0}, data), do: {[], data}
  defp decode_type({:array, type, element_count}, data) do
    repeated_type = Enum.map(1..element_count, fn _ -> type end)

    {tuple, rest} = decode_type({:tuple, repeated_type}, data)

    {tuple |> Tuple.to_list, rest}
  end

  defp decode_type({:tuple, types}, starting_data) do
    # First pass, decode static types
    {elements, rest} = Enum.reduce(types, {[], starting_data}, fn type, {elements, data} ->
      if ABI.FunctionSelector.is_dynamic?(type) do
        {tail_position, rest} = decode_type({:uint, 256}, data)

        {[{:dynamic, type, tail_position}|elements], rest}
      else
        {el, rest} = decode_type(type, data)

        {[el|elements], rest}
      end
    end)

    # Second pass, decode dynamic types
    {elements, rest} = Enum.reduce(elements |> Enum.reverse, {[], rest}, fn el, {elements, data} ->
      case el do
        {:dynamic, type, _tail_position} ->
          {el, rest} = decode_type(type, data)

          {[el|elements], rest}
        _ ->
          {[el|elements], data}
      end
    end)

    {elements |> Enum.reverse |> List.to_tuple, rest}
  end

  defp decode_type(els, _) do
    raise "Unsupported decoding type: #{inspect els}"
  end

  @spec decode_uint(binary(), integer()) :: {integer(), binary()}
  defp decode_uint(data, size_in_bits) do
    # TODO: Create `left_pad` repo, err, add to `ExthCrypto.Math`
    total_bit_size = size_in_bits + ExthCrypto.Math.mod(256 - size_in_bits, 256)

    <<value::integer-size(total_bit_size), rest::binary>> = data

    {value, rest}
  end

  @spec decode_bytes(binary(), integer(), atom()) :: {binary(), binary()}
  def decode_bytes(data, size_in_bytes, padding_direction) do
    # TODO: Create `unright_pad` repo, err, add to `ExthCrypto.Math`
    total_size_in_bytes = size_in_bytes + ExthCrypto.Math.mod(32 - size_in_bytes, 32)
    padding_size_in_bytes = total_size_in_bytes - size_in_bytes

    case padding_direction do
      :left ->
        <<_padding::binary-size(padding_size_in_bytes), value::binary-size(size_in_bytes), rest::binary()>> = data

        {value, rest}
      :right ->
        <<value::binary-size(size_in_bytes), _padding::binary-size(padding_size_in_bytes), rest::binary()>> = data

        {value, rest}
    end
  end

end
