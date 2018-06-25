defmodule EthCore.Block.Header.DifficultyTest do
  use ExUnit.Case

  doctest EthCore.Block.Header.Difficulty

  alias EthCore.Block.Header
  alias EthCore.Block.Header.Difficulty

  describe "calc/6" do
    test "low timestamp, no parent" do
      header = %Header{number: 0, timestamp: 55}
      assert Difficulty.calc(header, nil) == 131_072
    end

    test "genesis parent" do
      parent = %Header{number: 0, timestamp: 0, difficulty: 1_048_576}
      header = %Header{number: 1, timestamp: 1479642530}
      assert Difficulty.calc(header, parent) == 1_048_064
    end

    test "timestamp 66, non-genesis parent" do
      parent = %Header{number: 32, timestamp: 55, difficulty: 300_000}
      header = %Header{number: 33, timestamp: 66}
      assert Difficulty.calc(header, parent) == 300_146
    end

    test "timestamp 88, non-genesis parent" do
      parent = %Header{number: 32, timestamp: 55, difficulty: 300_000}
      header = %Header{number: 33, timestamp: 88}
      assert Difficulty.calc(header, parent) == 299_854
    end

    test "high block number, low timestamp" do
      # TODO: Is this right? These numbers are quite a jump
      parent = %Header{number: 3_000_000, timestamp: 55, difficulty: 300_000}
      header = %Header{number: 3_000_001, timestamp: 66}
      assert Difficulty.calc(header, parent) == 268_735_456
    end

    test "high block number, high timestamp" do
      parent = %Header{number: 3_000_000, timestamp: 55, difficulty: 300_000}
      header = %Header{number: 3_000_001, timestamp: 155}
      assert Difficulty.calc(header, parent) == 268_734_142
    end

    test "the genesis block of Ropsten chain" do
      header = %Header{number: 0, timestamp: 0}
      difficulty = Difficulty.calc(header, nil, 0x100000, 0x020000, 0x0800, 0)
      assert difficulty == 1_048_576
    end

    test "the first block of Ropsten chain" do
      parent = %Header{number: 0, timestamp: 0, difficulty: 1_048_576}
      header = %Header{number: 1, timestamp: 1_479_642_530}
      difficulty = Difficulty.calc(header, parent, 0x100000, 0x020000, 0x0800, 0)
      assert difficulty == 997_888
    end
  end
end
