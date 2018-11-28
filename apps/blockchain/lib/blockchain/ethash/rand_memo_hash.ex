defmodule Blockchain.Ethash.RandMemoHash do
  alias Blockchain.Ethash
  alias ExthCrypto.Hash.Keccak

  use Bitwise

  @type optimized_cache :: %{non_neg_integer() => <<_::512>>}

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

    cache = optimized_cache(original_cache)

    0..(n - 1)
    |> Enum.reduce(cache, fn index, modified_cache ->
      rmh(index, n, modified_cache)
    end)
    |> return_cache_to_list()
  end

  defp return_cache_to_list(cache_as_map) do
    Enum.map(cache_as_map, fn {_k, v} -> v end)
  end

  defp optimized_cache(original_cache) do
    original_cache
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {v, k}, acc ->
      Map.put(acc, k, v)
    end)
  end

  @spec rmh(integer(), non_neg_integer(), optimized_cache()) :: optimized_cache()
  defp rmh(i, n, cache) do
    first_index = first_index(i, n)
    second_index = second_index(i, n, cache)

    %{^first_index => first_element, ^second_index => second_element} = cache

    updated_element = Keccak.kec512(:crypto.exor(first_element, second_element))

    Map.put(cache, i, updated_element)
  end

  @spec first_index(integer(), non_neg_integer()) :: integer()
  defp first_index(i, n) do
    Integer.mod(i - 1 + n, n)
  end

  @spec second_index(integer(), non_neg_integer(), optimized_cache()) :: integer()
  defp second_index(i, n, cache) do
    %{^i => cache_element} = cache

    <<header::size(8), _rest::binary>> = cache_element

    Integer.mod(header, n)
  end
end
