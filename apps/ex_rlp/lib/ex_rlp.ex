defmodule ExRlp do
  def encode(item) when is_binary(item) and byte_size(item) == 1 do
    item
  end

  def encode(item) when is_binary(item) and byte_size(item) < 56 do
    prefix = 128 + byte_size(item)

    << prefix >> <> item
  end

  def encode(item) when is_binary(item) do
    big_endian_size =
      item
      |> byte_size
      |> :binary.encode_unsigned
    byte_size = byte_size(big_endian_size)

    << 183 + byte_size >> <> big_endian_size <> item
  end
end
