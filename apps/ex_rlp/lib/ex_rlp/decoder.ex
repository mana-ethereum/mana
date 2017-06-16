defmodule ExRLP.Decoder do
  alias ExRLP.Prefix

  def decode(item) when is_binary(item) do
    item
    |> decode_hex
    |> decode_item
  end

  defp decode_item(rlp_binary, result \\ [], in_list \\ false)

  defp decode_item("", result, in_list) do
    result
  end

  defp decode_item(<< << prefix >>, tail :: binary >>, _result, false) when prefix < 128 do
    item = << prefix >>

    decode_item("", item)
  end

  defp decode_item(<< << prefix >>, tail :: binary >>, result, in_list) when prefix < 128 do
    new_item = << prefix >>

    new_result = result ++ [new_item]
    decode_item(tail, new_result, in_list)
  end

  defp decode_item(<< << prefix >>, item :: binary >>, _result, false) when prefix <= 183 do
    decode_item("", item)
  end

  defp decode_item(<< << prefix >>, tail :: binary >>, result, in_list) when prefix <= 183 do
    item_length = prefix - 128

    << new_item :: binary-size(item_length), new_tail :: binary >> = tail

    new_result = result ++ [new_item]
    decode_item(new_tail, new_result, in_list)
  end

  defp decode_item(<< << be_size_prefix >>, tail :: binary >>, result, false) when be_size_prefix < 192 do
    be_size = be_size_prefix - 183

    << be :: binary-size(be_size), data :: binary >> = tail
    item_length = be |> :binary.decode_unsigned
    << item :: binary-size(item_length), new_tail :: binary >> = data

    decode_item("", item)
  end

  defp decode_item(<< << be_size_prefix >>, tail :: binary >>, result, in_list) when be_size_prefix < 192 do
    be_size = be_size_prefix - 183

    << be :: binary-size(be_size), data :: binary >> = tail
    item_length = be |> :binary.decode_unsigned
    << new_item :: binary-size(item_length), new_tail :: binary >> = data

    new_result = result ++ [new_item]
    decode_item(new_tail, new_result, in_list)
  end

  defp decode_item(<< << be_size_prefix >>, tail :: binary >>, result, in_list) when be_size_prefix == 192 do
    new_result = if in_list, do: [[]], else: []
    new_result = if length(result) == 0, do: [[]], else: result ++ [[]]
    decode_item(tail, new_result, in_list)
  end

  defp decode_item(<< << prefix >>, tail :: binary >>, result, in_list) when prefix <= 247 do
    list_length = prefix - 192

    << list :: binary-size(list_length), new_tail :: binary >> = tail

    list_items = decode_item(list, [], true)
    list_items = if in_list, do: [list_items], else: list_items
    new_result = if length(result) == 0, do: list_items, else: result ++ [list_items]
    decode_item(new_tail, new_result)
  end

  defp decode_item(<< << be_size_prefix >>, tail :: binary >>, result, in_list) do
    be_size = be_size_prefix - 247

    << be :: binary-size(be_size), data :: binary >> = tail
    list_length = be |> :binary.decode_unsigned
    << list :: binary-size(list_length), new_tail :: binary >> = data

    list_items = decode_item(list, [], true)
    new_result = if length(result) == 0, do: list_items, else: result ++ [list_items]
    decode_item(new_tail, new_result)
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
