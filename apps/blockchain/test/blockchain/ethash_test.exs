defmodule Blockchain.EthashTest do
  use ExUnit.Case, async: true

  alias Blockchain.Ethash

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
end
