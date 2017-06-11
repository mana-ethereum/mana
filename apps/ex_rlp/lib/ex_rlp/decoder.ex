defmodule ExRLP.Decoder do

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
    << be_size_prefix :: binary-size(1), data_with_be :: binary >> = item
    << be_size_prefix >> = be_size_prefix
    be_size = be_size_prefix - 183
    << _prefix :: binary-size(be_size), data :: binary >> = data_with_be

    data
  end

  defp decode_item(item, :integer) do
    item
    |> decode_item(:binary)
    |> :binary.decode_unsigned
  end

  defp decode_hex(binary) do
    {:ok, decoded_binary} = binary |> Base.decode16(case: :lower)

    decoded_binary
  end
end
