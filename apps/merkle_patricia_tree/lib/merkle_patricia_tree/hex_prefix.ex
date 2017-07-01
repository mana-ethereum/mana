defmodule MerklePatriciaTree.HexPrefix do

  def to_nibbles(binary, result \\ [])

  def to_nibbles(<< << byte >>, tail :: binary >>, result) do
    first_nibble = div(byte, 16)
    second_nibble = rem(byte, 16)

    current_result = result ++ [first_nibble, second_nibble]

    to_nibbles(tail, current_result)
  end

  def to_nibbles(<<>>, result) do
    result
  end

  def encode(nibbles) when is_list(nibbles) do
    {nibbles, term} = nibbles |> term?
    odd = nibbles |> odd?

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
    term = last_nibble == 16
    nibbles = if term, do: nibbles |> Enum.drop(-1), else: nibbles

    {nibbles, term}
  end

  defp add_flags(nibbles, 0, term) do
    first_nibble = [f(term), 0]

    first_nibble ++ nibbles
  end

  defp add_flags(nibbles, _oddness, term) do
    first_nibble = f(term) + 1

    [first_nibble | nibbles]
  end

  defp encode_nibbles(nibbles, result \\ [])

  defp encode_nibbles([], result) do
    result
  end

  defp encode_nibbles([prev_nibble | [cur_nibble | tail]], result) do
    cur_enc = [16 * prev_nibble + cur_nibble]

    encode_nibbles(tail, result ++ cur_enc)
  end

  defp f(true) do
    2
  end

  defp f(_) do
    0
  end
end
