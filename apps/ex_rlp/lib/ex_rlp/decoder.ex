defmodule ExRLP.Decoder do
  alias ExRLP.Prefix

  def decode(item, type \\ :binary) when is_binary(item) do
    item
    |> decode_hex
    |> decode_item(type)
  end

  defp decode_item(<< byte >> = item, :binary) when byte < 128 do
    item
  end

  defp decode_item(<< 128 >>, :binary) do
    ""
  end

  defp decode_item(item, :binary) when byte_size(item) <= 56  do
    << _prefix :: binary-size(1), data :: binary >> = item

    data
  end

  defp decode_item(item, :binary) do
    item |> binary_without_prefix(Prefix.binary)
  end

  defp decode_item(item, :integer) do
    item
    |> decode_item(:binary)
    |> :binary.decode_unsigned
  end

  defp decode_item(items, :list) when byte_size(items) <= 56 do
    << _prefix :: binary-size(1), encoded_items :: binary >> = items

    encoded_items |> decode_list_items([])
  end

  defp decode_list_items("", items) do
    items
  end

  defp decode_list_items(<< << prefix >>, tail :: binary >>, items) do
    cond do
      prefix < Prefix.short_binary ->
        items = items ++ [prefix]
        decode_list_items(tail,  items)
      prefix < Prefix.binary ->
        size = prefix - Prefix.short_binary
        <<item :: binary-size(size), new_tail :: binary>> = tail
        items = items ++ [item]

        decode_list_items(new_tail, items)
    end
  end

  defp binary_without_prefix(binary, prefix) do
    << be_size_prefix :: binary-size(1), data_with_be :: binary >> = binary
    << be_size_prefix >> = be_size_prefix
    be_size = be_size_prefix - prefix
    << _prefix :: binary-size(be_size), data :: binary >> = data_with_be

    data
  end

  defp decode_hex(binary) do
    {:ok, decoded_binary} = binary |> Base.decode16(case: :lower)

    decoded_binary
  end
end
