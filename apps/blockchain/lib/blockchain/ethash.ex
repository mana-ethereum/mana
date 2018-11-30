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
  @j_accesses 64
  @hash_words div(@j_hashbytes, @j_wordbytes)
  @mix_hash div(@j_mixbytes, @j_hashbytes)
  @mix_length div(@j_mixbytes, @j_wordbytes)
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
  @type cache :: %{non_neg_integer => <<_::512>>}
  @type seed :: <<_::256>>
  @type mix :: list(non_neg_integer)
  @type mix_digest :: <<_::256>>
  @type result :: <<_::256>>
  @type nonce :: non_neg_integer()

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
  Implementation of the Proof-of-work algorithm that uses the full dataset.

  For more information, see Appendix J, section J.4 of the Yellow Paper.
  """
  @spec pow_full(dataset(), binary(), nonce()) :: {mix_digest(), result()}
  def pow_full(dataset, block_hash, nonce) do
    size = length(dataset)

    pow(block_hash, nonce, size, &Enum.at(dataset, &1))
  end

  @doc """
  Implementation of the Proof-of-work algorithm that uses a cache instead of the
  full dataset.

  For more information, see Appendix J, section J.4 of the Yellow Paper.
  """
  @spec pow_light(non_neg_integer, cache(), binary(), nonce()) :: {mix_digest(), result()}
  def pow_light(full_size, cache, block_hash, nonce) do
    adjusted_size = div(full_size, @j_hashbytes)
    dataset_lookup = &calculate_dataset_item(cache, &1, map_size(cache))

    pow(block_hash, nonce, adjusted_size, dataset_lookup)
  end

  defp pow(block_hash, nonce, dataset_size, dataset_lookup) do
    seed_hash = combine_header_and_nonce(block_hash, nonce)

    [seed_head | _rest] = binary_into_uint32_list(seed_hash)

    mix =
      seed_hash
      |> init_mix_with_replication()
      |> mix_random_dataset_nodes(seed_head, dataset_size, dataset_lookup)
      |> compress_mix()
      |> uint32_list_into_binary()

    result = Keccak.kec(seed_hash <> mix)

    {mix, result}
  end

  defp compress_mix(mix) do
    mix
    |> Enum.chunk_every(4)
    |> Enum.map(fn [a, b, c, d] ->
      a
      |> FNV.hash(b)
      |> FNV.hash(c)
      |> FNV.hash(d)
    end)
  end

  defp mix_random_dataset_nodes(init_mix, seed_head, dataset_size, dataset_lookup) do
    dataset_length = div(dataset_size, @mix_hash)

    Enum.reduce(0..(@j_accesses - 1), init_mix, fn j, mix ->
      new_data =
        j
        |> bxor(seed_head)
        |> FNV.hash(Enum.at(mix, Integer.mod(j, @mix_length)))
        |> Integer.mod(dataset_length)
        |> generate_new_data(dataset_lookup)

      FNV.hash_lists(mix, new_data)
    end)
  end

  defp generate_new_data(parent, dataset_lookup) do
    0..(@mix_hash - 1)
    |> Enum.reduce([], fn k, data ->
      element = dataset_lookup.(@mix_hash * parent + k)
      [element | data]
    end)
    |> Enum.reverse()
    |> Enum.map(&binary_into_uint32_list/1)
    |> List.flatten()
  end

  defp init_mix_with_replication(seed_hash) do
    seed_hash
    |> List.duplicate(@mix_hash)
    |> List.flatten()
    |> Enum.map(&binary_into_uint32_list/1)
    |> List.flatten()
  end

  defp combine_header_and_nonce(block_hash, nonce) do
    Keccak.kec512(block_hash <> nonce_into_64bit(nonce))
  end

  defp nonce_into_64bit(nonce) do
    nonce
    |> :binary.encode_unsigned(:little)
    |> BitHelper.pad(8, :little)
  end

  @doc """
  Generates the dataset, d, outlined in Appendix J section J.3.3 of the Yellow
  Paper. For each element d[i] we combine data from 256 pseudorandomly selected
  cache nodes, and hash that to compute the dataset.
  """
  @spec generate_dataset(cache, non_neg_integer) :: dataset
  def generate_dataset(cache, full_size) do
    limit = div(full_size, @j_hashbytes)
    cache_size = map_size(cache)

    0..(limit - 1)
    |> Task.async_stream(&calculate_dataset_item(cache, &1, cache_size))
    |> Enum.into([], fn {:ok, value} -> value end)
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

    uint32_cache =
      Enum.into(cache, %{}, fn {i, element} ->
        {i, binary_into_uint32_list(element)}
      end)

    Enum.reduce(range, init_mix, fn j, mix ->
      cache_element = fnv_cache_element(index, j, mix, uint32_cache, cache_size)

      FNV.hash_lists(mix, cache_element)
    end)
  end

  defp fnv_cache_element(index, parent, mix, uint32_cache, cache_size) do
    mix_index = Integer.mod(parent, @hash_words)

    cache_index =
      index
      |> bxor(parent)
      |> FNV.hash(Enum.at(mix, mix_index))
      |> Integer.mod(cache_size)

    Map.fetch!(uint32_cache, cache_index)
  end

  defp cache_into_indexed_map(original_cache) do
    original_cache
    |> Enum.with_index()
    |> Enum.into(%{}, fn {v, k} -> {k, v} end)
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
    index = Integer.mod(i, cache_size)
    <<head::little-integer-size(32), rest::binary>> = Map.fetch!(cache, index)

    new_head = bxor(head, i)
    Keccak.kec512(<<new_head::little-integer-size(32)>> <> rest)
  end

  @doc """
  Generates the cache, c, outlined in Appendix J section J.3.2 of the Yellow
  Paper, by performing the RandMemoHash algorithm 3 times on the initial cache
  """
  @spec generate_cache(seed(), integer()) :: cache()
  def generate_cache(seed, cache_size) do
    seed
    |> initial_cache(cache_size)
    |> cache_into_indexed_map()
    |> calculate_cache(@j_cacherounds)
  end

  defp calculate_cache(cache, 0), do: cache

  defp calculate_cache(cache, number_of_rounds) do
    calculate_cache(RandMemoHash.hash(cache), number_of_rounds - 1)
  end

  defp initial_cache(seed, cache_size) do
    adjusted_cache_size = div(cache_size, @j_hashbytes)

    do_initial_cache(0, adjusted_cache_size - 1, seed, [])
  end

  defp do_initial_cache(limit, limit, _seed, acc = [previous | _rest]) do
    result = Keccak.kec512(previous)
    [result | acc] |> Enum.reverse()
  end

  defp do_initial_cache(0, limit, seed, []) do
    result = Keccak.kec512(seed)
    do_initial_cache(1, limit, seed, [result])
  end

  defp do_initial_cache(element, limit, seed, acc = [previous | _rest]) do
    result = Keccak.kec512(previous)
    do_initial_cache(element + 1, limit, seed, [result | acc])
  end
end
