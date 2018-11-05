defmodule Blockchain.EthashTest do
  use ExUnit.Case, async: true

  alias Blockchain.Ethash
  alias Blockchain.Ethash.RandMemoHash
  alias ExthCrypto.Hash.Keccak

  test "it can calculate the epoch from block number" do
    results =
      [1, 29_999, 30_000, 90_000]
      |> Enum.map(&Ethash.epoch/1)

    assert results == [0, 0, 1, 3]
  end

  describe "dataset_size/2" do
    test "calculates dataset size" do
      result = Ethash.dataset_size(1, [])

      assert result == 1_082_130_304
    end

    test "uses default cache up to 2048 epochs" do
      results =
        [0, 1, 2047]
        |> Enum.map(&Ethash.dataset_size/1)

      assert results == [1_073_739_904, 1_082_130_304, 18_245_220_736]
    end
  end

  describe "cache_size/2" do
    test "calculates cache size" do
      result = Ethash.cache_size(0, [])

      assert result == 16_776_896
    end

    test "uses default cache up to 2048 epochs" do
      results =
        [0, 2047]
        |> Enum.map(&Ethash.cache_size/1)

      assert results == [16_776_896, 285_081_536]
    end
  end

  describe "seed_hash/1" do
    test "returns the seed hash for block 1" do
      result = Ethash.seed_hash(1)

      assert result == <<0::256>>
    end

    test "returns a keccak of the original seed hash for 30000 < block < 60000" do
      previous_seed_hash = Ethash.seed_hash(1)

      result = Ethash.seed_hash(50_000)

      assert result == Keccak.kec(previous_seed_hash)
    end

    test "returns a keccak of the previous seed hash for every other block" do
      previous_seed_hash = Ethash.seed_hash(50_000)

      result = Ethash.seed_hash(70_000)

      assert result == Keccak.kec(previous_seed_hash)
    end
  end

  describe "calculate_cache/2" do
    test "returns initial cache if number of rounds is 0" do
      seed = <<0::256>>
      cache_size = 64
      initial_cache = Ethash.initial_cache(seed, cache_size)

      cache = Ethash.calculate_cache(initial_cache, 0)

      assert cache == initial_cache
    end

    test "returns the RandMemoHash of the initial cache for round 1" do
      seed = <<0::256>>
      cache_size = 64
      initial_cache = Ethash.initial_cache(seed, cache_size)

      cache = Ethash.calculate_cache(initial_cache, 1)

      assert cache == RandMemoHash.hash(initial_cache)
    end

    test "returns n rounds of rand memo hash on the initial cache" do
      seed = <<0::256>>
      cache_size = 64
      initial_cache = Ethash.initial_cache(seed, cache_size)

      cache = Ethash.calculate_cache(initial_cache, 2)

      assert cache == RandMemoHash.hash(RandMemoHash.hash(initial_cache))
    end
  end

  describe "initial_cache/3" do
    test "returns the initial cache for a given cache size" do
      seed = <<0::256>>
      # j_hashbytes = 64
      cache_size = 2 * 64
      element0 = Keccak.kec512(seed)
      element1 = Keccak.kec512(element0)

      cache = Ethash.initial_cache(seed, cache_size)

      assert cache == [element0, element1]
    end
  end

  describe "cache_element/1" do
    test "returns the kec 512 of the seed for element 0" do
      element = 0
      seed = <<0::256>>

      result = Ethash.cache_element(element, seed)

      assert result == Keccak.kec512(seed)
    end

    test "returns the kec 512 of the previous element of the cache" do
      element = 1
      seed = <<0::256>>
      previous_element_cache = Keccak.kec512(seed)

      result = Ethash.cache_element(element, seed)

      assert result == Keccak.kec512(previous_element_cache)
    end
  end
end
