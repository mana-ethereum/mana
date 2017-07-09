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

  def hex_prefix(nibbles) when is_list(nibbles) do
    nibbles |> HexPrefix.encode
  end

  def add_terminator(nibbles) when is_list(nibbles) do
    nibbles ++ [16]
  end

  def remove_terminator(nibbles) when is_list(nibbles) do
    nibbles -- [16]
  end
end
