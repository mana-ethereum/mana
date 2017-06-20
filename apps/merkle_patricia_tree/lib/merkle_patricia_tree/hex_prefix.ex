defmodule MerklePatriciaTree.HexPrefix do
  def encode(nibbles) when is_list(nibbles) do
    odd = nibbles |> odd?
    term = nibbles |> term?

    nibbles
    |> add_flags(odd, term)
    |> encode_nibbles
  end

  defp odd?(nibbles) do
    nibbles
    |> Enum.count
    |> rem(2)
  end

  defp term?(nibbles) do
    last_nibble = nibbles |> List.last

    last_nibble == 16
  end

  defp add_flags(nibbles, 0, term) do
    first_nibble = [16 * f(term), 0]

    first_nibble ++ nibbles
  end

  defp add_flags([first_nibble | nibbles], _oddness, term) do
    new_first_nibbles = 16 * (f(term) + 1) + first_nibble

    [new_first_nibbles | nibbles]
  end

  defp encode_nibbles(nibbles, prev_nibble \\ nil, result \\ "")

  defp encode_nibbles([], _, result) do
    result
  end

  defp encode_nibbles([nibble | tail], nil, result) do
    encode_nibbles(tail, nibble, result)
  end

  defp encode_nibbles([nibble | tail], prev_nibble, result) do
    cur_enc = 16 * prev_nibble + nibble
    cur_enc = << cur_enc :: size(16) >>

    encode_nibbles(tail, nibble, result <> cur_enc)
  end

  defp f(true) do
    2
  end

  defp f(_) do
    0
  end
end
