defmodule Blockchain.Ethash do
  @moduledoc """
  This module contains the logic found in Appendix J of the
  yellow paper concerning the Ethash implementation for POW.
  """

  alias ExthCrypto.Hash.Keccak

  @j_epoch 30_000
  @j_datasetinit round(:math.pow(2, 30))
  @j_datasetgrowth round(:math.pow(2, 23))
  @j_mixbytes 128
  @j_cacheinit round(:math.pow(2, 24))
  @j_cachegrowth round(:math.pow(2, 17))
  @j_hashbytes 64

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
end
