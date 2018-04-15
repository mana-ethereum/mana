defmodule ExRLP.Decode do
  @moduledoc false

  @spec decode(binary(), :binary | :hex) :: ExRLP.t()
  def decode(item, encoding) when is_binary(item) do
    item
    |> maybe_decode_hex(encoding)
    |> decode_item
  end

  @spec maybe_decode_hex(binary(), atom()) :: binary()
  defp maybe_decode_hex(value, :binary), do: value
  defp maybe_decode_hex(value, :hex), do: decode_hex(value)

  @spec decode_item(binary(), ExRLP.t()) :: ExRLP.t()
  defp decode_item(rlp_binary, result \\ nil)

  defp decode_item("", result) do
    result
  end

  defp decode_item(<<(<<prefix>>), tail::binary>>, result) when prefix < 128 do
    new_item = <<prefix>>

    new_result = result |> add_new_item(new_item)

    decode_item(tail, new_result)
  end

  defp decode_item(<<(<<prefix>>), tail::binary>>, result) when prefix <= 183 do
    {new_item, new_tail} = decode_medium_binary(prefix, tail, 128)

    new_result = result |> add_new_item(new_item)

    decode_item(new_tail, new_result)
  end

  defp decode_item(<<(<<be_size_prefix>>), tail::binary>>, result) when be_size_prefix < 192 do
    {new_item, new_tail} = decode_long_binary(be_size_prefix, tail, 183)

    new_result = result |> add_new_item(new_item)

    decode_item(new_tail, new_result)
  end

  defp decode_item(<<(<<be_size_prefix>>), tail::binary>>, result) when be_size_prefix == 192 do
    new_item = []

    new_result = result |> add_new_item(new_item)

    decode_item(tail, new_result)
  end

  defp decode_item(<<(<<prefix>>), tail::binary>>, result) when prefix <= 247 do
    {list, new_tail} = decode_medium_binary(prefix, tail, 192)

    new_result = result |> add_decoded_list(list)

    decode_item(new_tail, new_result)
  end

  defp decode_item(<<(<<be_size_prefix>>), tail::binary>>, result) do
    {list, new_tail} = decode_long_binary(be_size_prefix, tail, 247)

    new_result = result |> add_decoded_list(list)

    decode_item(new_tail, new_result)
  end

  @spec add_new_item(ExRLP.t(), ExRLP.t()) :: ExRLP.t()
  def add_new_item(nil, new_item) do
    new_item
  end

  def add_new_item(result, new_item) do
    result ++ [new_item]
  end

  @spec add_decoded_list(ExRLP.t(), binary()) :: ExRLP.t()
  defp add_decoded_list(nil, rlp_list_binary) do
    decode_item(rlp_list_binary, [])
  end

  defp add_decoded_list(result, rlp_list_binary) do
    list_items = decode_item(rlp_list_binary, [])

    result ++ [list_items]
  end

  @spec decode_medium_binary(integer(), binary(), integer()) :: {binary(), binary()}
  defp decode_medium_binary(length_prefix, tail, prefix) do
    item_length = length_prefix - prefix
    <<item::binary-size(item_length), new_tail::binary>> = tail

    {item, new_tail}
  end

  @spec decode_long_binary(integer(), binary(), integer()) :: {binary(), binary()}
  defp decode_long_binary(be_size_prefix, tail, prefix) do
    be_size = be_size_prefix - prefix
    <<be::binary-size(be_size), data::binary>> = tail

    item_length = be |> :binary.decode_unsigned()
    <<item::binary-size(item_length), new_tail::binary>> = data

    {item, new_tail}
  end

  @spec decode_hex(binary()) :: binary()
  defp decode_hex(binary) do
    {:ok, decoded_binary} = binary |> Base.decode16(case: :lower)

    decoded_binary
  end
end

defprotocol ExRLP.Decoder do
  def decode(value, type \\ :binary, options \\ nil)
end

defimpl ExRLP.Decoder, for: BitString do
  alias ExRLP.Decode

  @spec decode(binary(), atom(), keyword()) :: ExRLP.t()
  def decode(value, type \\ :binary, options \\ [])

  def decode(value, :map, options) do
    keys =
      options
      |> Keyword.get(:keys, [])
      |> Enum.sort()

    value
    |> Decode.decode(Keyword.get(options, :encoding, :binary))
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {value, index}, acc ->
      key = keys |> Enum.at(index)

      acc |> Map.put(key, value)
    end)
  end

  def decode(value, :binary, options) do
    value |> Decode.decode(Keyword.get(options, :encoding, :binary))
  end
end
