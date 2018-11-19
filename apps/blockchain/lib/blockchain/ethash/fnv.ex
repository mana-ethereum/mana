defmodule Blockchain.Ethash.FNV do
  use Bitwise

  @mod round(:math.pow(2, 32))
  @prime 0x01000193

  def hash_lists(x, y) when is_list(x) and is_list(y) do
    for i <- 0..(length(x) - 1) do
      hash(Enum.at(x, i), Enum.at(y, i))
    end
  end

  def hash(x, y) do
    first_element = bxor(x * @prime, y)
    Integer.mod(first_element, @mod)
  end
end
