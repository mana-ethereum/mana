defmodule MerklePatriciaTree.HexPrefix do
  def encode_nibbles(nibbles) when is_list(nibbles) do
    odd = nibbles |> odd?
    term = nibbles |> term?

    nibbles |> encode(odd, term)
  end

  def odd?(nibbles)
    rem =
      nibbles
      |> size
      |> rem(2)

    rem == 0
  end

  def term?(nibbles) do
    last_nibble = nibbles |> List.last

    last_nibble == 16
  end

  def encode(nibbles, true, term) do

  end

  def first_nibble(oddness, term) do
    oddness_part = if oddness == 0, do: 0, else: 1
    term_part = if term, do: 2, else: 0

    16 * term_part + oddness_part
  end
end
