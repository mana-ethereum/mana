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

  def to_binary(nibbles) when is_list(nibbles) do
    nibbles
    |> Enum.chunk(2)
    |> Enum.map(fn([first_nibble, second_nibble]) ->
      first_nibble * 16 + second_nibble
    end)
    |> to_string
  end

  def hex_prefix(nibbles) when is_list(nibbles) do
    nibbles |> HexPrefix.encode
  end

  def add_terminator(nibbles) when is_list(nibbles) do
    nibbles ++ [16]
  end
end
