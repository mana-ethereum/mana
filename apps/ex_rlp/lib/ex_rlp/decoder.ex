defmodule ExRLP.Decoder do
  @moduledoc false

  def decode(item) when is_binary(item) do
    item
    |> decode_hex
    |> decode_item
  end

  defp decode_item(rlp_binary, result \\ nil)

  defp decode_item("", result) do
    result
  end

  defp decode_item(<< << prefix >>, _tail :: binary >>, nil) when prefix < 128 do
    item = << prefix >>

    decode_item("", item)
  end

  defp decode_item(<< << prefix >>, tail :: binary >>, result) when prefix < 128 do
    new_item = << prefix >>

    new_result = result ++ [new_item]
    decode_item(tail, new_result)
  end

  defp decode_item(<< << prefix >>, item :: binary >>, nil) when prefix <= 183 do
    decode_item("", item)
  end

  defp decode_item(<< << prefix >>, tail :: binary >>, result) when prefix <= 183 do
    item_length = prefix - 128
    << new_item :: binary-size(item_length), new_tail :: binary >> = tail

    new_result = result ++ [new_item]

    decode_item(new_tail, new_result)
  end

  defp decode_item(<< << be_size_prefix >>, _tail :: binary >> = rlp_binary, nil) when be_size_prefix < 192 do
    {item, _} = rlp_binary |> decode_long_binary(183)

    decode_item("", item)
  end

  defp decode_item(<< << be_size_prefix >>, _tail :: binary >> = rlp_binary, result) when be_size_prefix < 192 do
    {new_item, new_tail} = rlp_binary |> decode_long_binary(183)

    new_result = result ++ [new_item]
    decode_item(new_tail, new_result)
  end

  defp decode_item(<< << be_size_prefix >>, tail :: binary >>, result) when be_size_prefix == 192 do
    new_result = if (length(result) == 0), do: [[]], else: result ++ [[]]
    decode_item(tail, new_result)
  end

  defp decode_item(<< << prefix >>, tail :: binary >>, result) when prefix <= 247 do
    list_length = prefix - 192
    << list :: binary-size(list_length), new_tail :: binary >> = tail

    new_result = result |> add_decoded_list(list)

    decode_item(new_tail, new_result)
  end

  defp decode_item(rlp_binary, result) do
    {list, new_tail} = rlp_binary |> decode_long_binary(247)

    new_result = result |> add_decoded_list(list)

    decode_item(new_tail, new_result)
  end

  defp add_decoded_list(result, rlp_list_binary) do
    list_items = decode_item(rlp_list_binary, [])

    if is_nil(result), do: list_items, else: result ++ [list_items]
  end

  defp decode_long_binary(<< << be_size_prefix >>, tail :: binary >>, prefix) do
    be_size = be_size_prefix - prefix

    << be :: binary-size(be_size), data :: binary >> = tail
    item_size = be |> :binary.decode_unsigned
    << item :: binary-size(item_size), new_tail :: binary >> = data

    {item, new_tail}
  end

  defp decode_hex(binary) do
    {:ok, decoded_binary} = binary |> Base.decode16(case: :lower)

    decoded_binary
  end
end
