defmodule Blockchain.Ethash.RandMemoHash do
  alias Blockchain.Ethash
  alias ExthCrypto.Hash.Keccak

  use Bitwise

  @doc """
  Computes the RandMemoHash algorithm for a list of binaries (as lists) as is
  outlined in Appendix J of the Yellow Paper.

  ```
  ERMH(x) =  [Ermh(x, 0), Ermh(x, 1), ..., Ermh(x, n - 1)]

  where
    Ermh(x, i) = KEC512(x'[(i - 1 + n) mod n] XOR x'[x'[i][0] mod n])
    with x' = x except x'[j] = Ermh(x,j) for all j < i
  ```
  """
  @spec hash(Ethash.cache()) :: Ethash.cache()
  def hash(original_cache) do
    n = length(original_cache)

    0..(n - 1)
    |> Enum.reduce(original_cache, fn index, modified_cache ->
      rmh(index, n, modified_cache)
    end)
  end

  @spec rmh(non_neg_integer(), non_neg_integer(), Ethash.cache()) :: Ethash.cache()
  defp rmh(i, n, cache) do
    first_element = Enum.at(cache, first_index(i, n))
    second_element = Enum.at(cache, second_index(i, n, cache))

    updated_element = Keccak.kec512(:crypto.exor(first_element, second_element))

    List.replace_at(cache, i, updated_element)
  end

  @spec first_index(integer(), non_neg_integer()) :: integer()
  defp first_index(i, n) do
    Integer.mod(i - 1 + n, n)
  end

  @spec second_index(integer(), integer(), Ethash.cache()) :: integer()
  defp second_index(i, n, cache) do
    cache_element = Enum.at(cache, i)

    <<header::size(8), _rest::binary>> = cache_element

    Integer.mod(header, n)
  end
end
