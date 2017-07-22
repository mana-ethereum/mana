defmodule MerklePatriciaTree.Nibbles do
  alias MerklePatriciaTree.Nibbles.HexPrefix

  def from_binary(binary, result \\ [])

  def from_binary(<< << byte >>, tail :: binary >>, result) do
    first_nibble = div(byte, 16)
    second_nibble = rem(byte, 16)

    current_result = result ++ [first_nibble, second_nibble]

    from_binary(tail, current_result)
  end

  def from_binary(<<>>, result) do
    result
  end

  def to_binary(nibbles, result \\ [])

  def to_binary([], result) do
    result
    |> Enum.reduce(<<>>, fn(byte, acc) ->
      acc <> << byte >>
    end)
  end

  def to_binary([prev_nibble | [cur_nibble | tail]], result) do
    cur_enc = [16 * prev_nibble + cur_nibble]

    to_binary(tail, result ++ cur_enc)
  end

  def hex_prefix_encode(nibbles) when is_list(nibbles) do
    nibbles |> HexPrefix.encode
  end

  def hex_prefix_decode(binary) when is_binary(binary) do
    binary |> HexPrefix.decode
  end

  def add_terminator(nibbles) when is_list(nibbles) do
    nibbles ++ [16]
  end

  def remove_terminator(nibbles) when is_list(nibbles) do
    nibbles -- [16]
  end

  def common_prefix_length(nibbles1, nibbles2, length \\ 0)

  def common_prefix_length([], _, length) do
    length
  end

  def common_prefix_length(_, [], length) do
    length
  end

  def common_prefix_length([nibble1 | tail1], [nibble2 | tail2], length) when nibble1 == nibble2 do
    common_prefix_length(tail1, tail2, length + 1)
  end

  def common_prefix_length(_, _, length)  do
    length
  end

  def starts_with?(nibbles1, nibbles2)

  def starts_with?(_, []) do
    true
  end

  def starts_with?([nibble1 | tail1], [nibble2 | tail2]) when nibble1 == nibble2 do
    starts_with?(tail1, tail2)
  end

  def starts_with?(_, _, length)  do
    false
  end
end
