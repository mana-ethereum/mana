defmodule ExRLP.Decoder do

  def decode(item) when is_binary(item) do
    item
    |> decode_hex
    |> decode_item
  end

  defp decode_item(<< byte >> = item) when byte < 128 do
    item
  end

  defp decode_item(<< 128 >>) do
    ""
  end

  defp decode_item(item) when byte_size(item) <= 56  do
    << _prefix :: binary-size(1), data :: binary >> = item

    data
  end

  defp decode_item(item) do
    << be_size_prefix :: binary-size(1), data_with_be :: binary >> = item
    << be_size_prefix >> = be_size_prefix
    be_size = be_size_prefix - 183
    << _prefix :: binary-size(be_size), data :: binary >> = data_with_be

    data
  end

  defp decode_hex(binary) do
    {:ok, decoded_binary} =
      binary
      |> Base.decode16(case: :lower)

    decoded_binary
  end
end
