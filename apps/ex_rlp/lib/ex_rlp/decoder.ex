defmodule ExRLP.Decoder do
  alias ExRLP.Prefix

  def decode(item) when is_binary(item) do
    item
    |> decode_hex
    |> decode_item
  end

  defp decode_item(rlp_binary, result \\ [])

  defp decode_item("", result) do
    result
  end

  defp decode_item(<< << prefix >>, tail :: binary >>, result) when prefix < 128 do
    new_item = << prefix >>

    decode_item(tail, [new_item | result])
  end

  defp decode_item(<< << prefix >>, tail :: binary >>, result) when prefix <= 183 do
    item_length = prefix - 128

    << new_item :: binary-size(item_length), new_tail :: binary >> = tail

    decode_item(new_tail, [new_item | result])
  end

  #   << be_size_prefix :: binary-size(1), data_with_be :: binary >> = binary
  #   << be_size_prefix >> = be_size_prefix
  #   be_size = be_size_prefix - prefix
  #   << _prefix :: binary-size(be_size), data :: binary >> = data_with_be

  #   data

  defp decode_item(<< << be_size_prefix >>, tail :: binary >>, result) do
    be_size = be_size_prefix - 183

    << be :: binary-size(be_size), data :: binary >> = tail
    item_length = be |> :binary.decode_unsigned
    << new_item :: binary-size(item_length), new_tail :: binary >> = data

    decode_item(new_tail, [new_item | result])
  end

  # defp decode_item(<< byte >> = item, :binary, _position) when byte < 128 do
  #   item
  # end

  # defp decode_item(<< 128 >> = item, :binary, _position) do
  #   ""
  # end

  # defp decode_item(rlp_binary, :binary, position) when byte_size(item) <= 56 and is_nil(position) do
  #   << item_size :: binary-size(1), data :: binary >> = item

  #   {data, nil}
  # end

  # defp decode_item(rlp_binary, :binary, position) when byte_size(item) <= 56 do
  #   << item_size :: binary-size(1), data :: binary >> = item
  # end

  # defp decode_item(item, :binary) do
  #   item |> binary_without_prefix(Prefix.binary)
  # end

  # defp decode_item(item, :integer) do
  #   item
  #   |> decode_item(:binary)
  #   |> :binary.decode_unsigned
  # end

  # defp decode_item(items, :list) when byte_size(items) <= 56 do
  #   << _prefix :: binary-size(1), encoded_items :: binary >> = items

  #   encoded_items |> decode_list_items
  # end

  # defp decode_item(items, :list) do
  #   encoded_items = items |> binary_without_prefix(Prefix.list)

  #   encoded_items |> decode_list_items
  # end

  # defp do
  # end

  # defp decode_list_items("", items) do
  #   items
  # end

  # defp decode_list_items(<< << prefix >>, tail :: binary >>, items \\ []) do
  #   cond do
  #     prefix < Prefix.short_binary ->
  #       items = items ++ [prefix]
  #       decode_list_items(tail,  items)
  #     prefix < Prefix.binary ->
  #       size = prefix - Prefix.short_binary
  #       <<item :: binary-size(size), new_tail :: binary>> = tail
  #       items = items ++ [item]

  #       decode_list_items(new_tail, items)
  #   end
  # end

  # defp binary_without_prefix(binary, prefix) do
  #   << be_size_prefix :: binary-size(1), data_with_be :: binary >> = binary
  #   << be_size_prefix >> = be_size_prefix
  #   be_size = be_size_prefix - prefix
  #   << _prefix :: binary-size(be_size), data :: binary >> = data_with_be

  #   data
  # end

  defp decode_hex(binary) do
    {:ok, decoded_binary} = binary |> Base.decode16(case: :lower)

    decoded_binary
  end
end
