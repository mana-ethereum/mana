defmodule Blockchain.Ethash do
  @moduledoc """
  This module contains the logic found in Appendix J of the
  yellow paper concerning the Ethash implementation for POW.
  """

  use Bitwise

  alias Blockchain.Ethash.{FNV, RandMemoHash}
  alias ExthCrypto.Hash.Keccak

  @j_epoch 30_000
  @j_datasetinit round(:math.pow(2, 30))
  @j_datasetgrowth round(:math.pow(2, 23))
  @j_mixbytes 128
  @j_cacheinit round(:math.pow(2, 24))
  @j_cachegrowth round(:math.pow(2, 17))
  @j_hashbytes 64
  @j_cacherounds 3
  @j_parents 256
  @j_wordbytes 4
  @hash_words div(@j_hashbytes, @j_wordbytes)
  @parents_range Range.new(0, @j_parents - 1)

  @precomputed_data_sizes [__DIR__, "ethash", "data_sizes.txt"]
                          |> Path.join()
                          |> File.read!()
                          |> String.split()
                          |> Enum.map(&String.to_integer/1)

  @precomputed_cache_sizes [__DIR__, "ethash", "cache_sizes.txt"]
                           |> Path.join()
                           |> File.read!()
                           |> String.split()
                           |> Enum.map(&String.to_integer/1)

  @first_epoch_seed_hash <<0::256>>

  @type dataset_item :: <<_::512>>
  @type dataset :: list(dataset_item)
  @type cache :: list(<<_::512>>)
  @type seed :: <<_::256>>
  @type mix :: list(non_neg_integer)

  def epoch(block_number) do
    div(block_number, @j_epoch)
  end

  def dataset_size(epoch, cache \\ @precomputed_data_sizes) do
    Enum.at(cache, epoch) || calculate_dataset_size(epoch)
  end

  defp calculate_dataset_size(epoch) do
    highest_prime_below_threshold(
      @j_datasetinit + @j_datasetgrowth * epoch - @j_mixbytes,
      unit_size: @j_mixbytes
    )
  end

  def cache_size(epoch, cache \\ @precomputed_cache_sizes) do
    Enum.at(cache, epoch) || calculate_cache_size(epoch)
  end

  defp calculate_cache_size(epoch) do
    highest_prime_below_threshold(
      @j_cacheinit + @j_cachegrowth * epoch - @j_hashbytes,
      unit_size: @j_hashbytes
    )
  end

  def seed_hash(block_number) do
    if epoch(block_number) == 0 do
      @first_epoch_seed_hash
    else
      Keccak.kec(seed_hash(block_number - @j_epoch))
    end
  end

  defp highest_prime_below_threshold(upper_bound, unit_size: unit_size) do
    adjusted_upper_bound = div(upper_bound, unit_size)

    if prime?(adjusted_upper_bound) and adjusted_upper_bound >= 0 do
      upper_bound
    else
      highest_prime_below_threshold(upper_bound - 2 * unit_size, unit_size: unit_size)
    end
  end

  defp prime?(num) do
    one_less = num - 1

    one_less..2
    |> Enum.find(fn a -> rem(num, a) == 0 end)
    |> is_nil
  end

  @doc """
  Generates the dataset, d, outlined in Appendix J section J.3.3 of the Yellow
  Paper. For each element d[i] we combine data from 256 pseudorandomly selected
  cache nodes, and hash that to compute the dataset.
  """
  @spec generate_dataset(cache, non_neg_integer) :: dataset
  def generate_dataset(cache, full_size) do
    limit = div(full_size, @j_hashbytes)
    cache_size = length(cache)

    for i <- 0..(limit - 1) do
      calculate_dataset_item(cache, i, cache_size)
    end
  end

  @spec calculate_dataset_item(cache, non_neg_integer, non_neg_integer) :: dataset_item
  defp calculate_dataset_item(cache, i, cache_size) do
    @parents_range
    |> generate_mix_of_uints(cache, cache_size, i)
    |> uint32_list_into_binary()
    |> Keccak.kec512()
  end

  @spec generate_mix_of_uints(Range.t(), cache, non_neg_integer, non_neg_integer) :: mix
  defp generate_mix_of_uints(range, cache, cache_size, index) do
    init_mix =
      cache
      |> initialize_mix(index, cache_size)
      |> binary_into_uint32_list()

    uint32_cache = Enum.map(cache, &binary_into_uint32_list/1)

    Enum.reduce(range, init_mix, fn j, mix ->
      cache_element = fnv_cache_element(index, j, mix, uint32_cache, cache_size)

      FNV.hash_lists(mix, cache_element)
    end)
  end

  defp fnv_cache_element(index, parent, mix, modified_cache, cache_size) do
    mix_index = Integer.mod(parent, @hash_words)

    cache_index =
      index
      |> bxor(parent)
      |> FNV.hash(Enum.at(mix, mix_index))
      |> Integer.mod(cache_size)

    Enum.at(modified_cache, cache_index)
  end

  @spec binary_into_uint32_list(binary) :: list(non_neg_integer)
  defp binary_into_uint32_list(binary) do
    for <<chunk::size(32) <- binary>> do
      <<chunk::size(32)>> |> :binary.decode_unsigned(:little)
    end
  end

  @spec uint32_list_into_binary(list(non_neg_integer)) :: binary()
  defp uint32_list_into_binary(list_of_uint32) do
    list_of_uint32
    |> Enum.map(&:binary.encode_unsigned(&1, :little))
    |> Enum.map(&BitHelper.pad(&1, 4, :little))
    |> Enum.join()
  end

  @spec initialize_mix(cache, non_neg_integer, non_neg_integer) :: binary
  defp initialize_mix(cache, i, cache_size) do
    cache
    |> Enum.at(Integer.mod(i, cache_size))
    |> :binary.decode_unsigned(:little)
    |> bxor(i)
    |> :binary.encode_unsigned(:little)
    |> Keccak.kec512()
  end

  @doc """
  Generates the cache, c, outlined in Appendix J section J.3.2 of the Yellow
  Paper, by performing the RandMemoHash algorithm 3 times on the initial cache
  """
  @spec generate_cache(seed(), integer()) :: cache()
  def generate_cache(seed, cache_size) do
    seed
    |> initial_cache(cache_size)
    |> calculate_cache(@j_cacherounds)
  end

  @spec calculate_cache(cache(), 0 | 1 | 2 | 3) :: cache()
  defp calculate_cache(cache, 0), do: cache

  defp calculate_cache(cache, number_of_rounds) do
    calculate_cache(RandMemoHash.hash(cache), number_of_rounds - 1)
  end

  @spec initial_cache(seed(), integer()) :: cache()
  defp initial_cache(seed, cache_size) do
    adjusted_cache_size = div(cache_size, @j_hashbytes)

    for i <- 0..(adjusted_cache_size - 1) do
      cache_element(i, seed)
    end
  end

  defp cache_element(0, seed), do: Keccak.kec512(seed)

  defp cache_element(element, seed) do
    Keccak.kec512(cache_element(element - 1, seed))
  end
end
