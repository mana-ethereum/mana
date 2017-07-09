defmodule MerklePatriciaTree.Nibbles.HexPrefix do
  import MerklePatriciaTree.Nibbles, only: [from_binary: 1, to_binary: 1]
  use Bitwise, only_operators: true

  def decode(hex_prefix_bin) when is_binary(hex_prefix_bin) do
    nibbles = hex_prefix_bin |> from_binary
    [flags | _] = nibbles

    nibbles = if (flags &&& 2) > 0, do: nibbles ++ [16], else: nibbles
    if (flags &&& 1) > 0, do: Enum.drop(nibbles, 1), else: Enum.drop(nibbles, 2)
  end

  def encode(nibbles) when is_list(nibbles) do
    {nibbles, term} = nibbles |> term?
    odd = nibbles |> odd?

    nibbles
    |> add_flags(odd, term)
    |> to_binary
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

  defp f(true) do
    2
  end

  defp f(_) do
    0
  end
end
