defmodule ExRLP.Decoder do
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
    #new_result = if in_list, do: [[]], else: []
    new_result = if (length(result) == 0), do: [[]], else: result ++ [[]]
    decode_item(tail, new_result, in_list)
  end

  defp decode_item(<< << prefix >>, tail :: binary >>, result, in_list) when prefix <= 247 do
    list_length = prefix - 192

    << list :: binary-size(list_length), new_tail :: binary >> = tail

    list_items = decode_item(list, [], true)
    list_items = if (in_list and length(list_items) != 1), do: [list_items], else: list_items
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

  defp decode_hex(binary) do
    {:ok, decoded_binary} = binary |> Base.decode16(case: :lower)

    decoded_binary
  end
end
