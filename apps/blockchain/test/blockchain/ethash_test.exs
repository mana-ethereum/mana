defmodule Blockchain.EthashTest do
  use ExUnit.Case, async: true

  alias Blockchain.Ethash
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
end
