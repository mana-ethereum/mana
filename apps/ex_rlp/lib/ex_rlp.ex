defmodule ExRLP do
  def encode(item) when is_binary(item) and byte_size(item) == 1 do
    item |> encode_hex
  end

  def encode(item) when is_binary(item) and byte_size(item) < 56 do
    prefix = 128 + byte_size(item)

    encoded_item = << prefix >> <> item
    encoded_item |> encode_hex
  end

  def encode(item) when is_binary(item) do
    big_endian_size =
      item
      |> byte_size
      |> :binary.encode_unsigned
    byte_size = byte_size(big_endian_size)

    encoded_item = << 183 + byte_size >> <> big_endian_size <> item
    encoded_item |> encode_hex
  end

  defp encode_hex(binary) do
    binary |> Base.encode16(case: :lower)
  end
end
