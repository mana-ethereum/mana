defmodule Blockchain.Ethash.FNV do
  use Bitwise

  @mod round(:math.pow(2, 32))
  @prime 0x01000193

  def hash_lists(x_list, y_list) do
    do_hash_lists(x_list, y_list, [])
  end

  defp do_hash_lists([], _, acc), do: Enum.reverse(acc)

  defp do_hash_lists([x | x_rest], [y | y_rest], acc) do
    do_hash_lists(x_rest, y_rest, [hash(x, y) | acc])
  end

  def hash(x, y) do
    first_element = bxor(x * @prime, y)
    Integer.mod(first_element, @mod)
  end
end
