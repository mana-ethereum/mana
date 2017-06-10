defmodule ExRLP do
  alias ExRLP.Serializer

  def encode(item) do
    item
    |> encode_item
    |> encode_hex
  end

  defp encode_item(item) when is_binary(item) and byte_size(item) == 1 do
    item
  end

  defp encode_item(item) when is_binary(item) and byte_size(item) < 56 do
    prefix = 128 + byte_size(item)

    << prefix >> <> item
  end

  defp encode_item(item) when is_binary(item) do
    be_size = item |> big_endian_size
    byte_size = be_size |> byte_size

    << 183 + byte_size >> <> be_size <> item
  end

  defp encode_item(items) when is_list(items) do
    encoded_concat =
      items
      |> Enum.reduce("", fn(item, acc) ->
        encoded_item = item |> encode_item

        acc <> encoded_item
      end)

    encoded_concat |> prefix_list
  end

  defp encode_item(item) do
    item
    |> Serializer.serialize
    |> encode_item
  end

  defp prefix_list(encoded_concat) when byte_size(encoded_concat) < 56 do
    size = encoded_concat |> byte_size

    << 192 + size >> <> encoded_concat
  end

  defp prefix_list(encoded_concat) do
    be_size = encoded_concat |> big_endian_size
    byte_size = be_size |> byte_size

    << 247 + byte_size >> <> be_size <> encoded_concat
  end

  defp big_endian_size(binary) do
    binary
    |> byte_size
    |> :binary.encode_unsigned
  end

  defp encode_hex(binary) do
    binary |> Base.encode16(case: :lower)
  end
end
