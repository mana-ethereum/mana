defmodule Blockchain.BloomTest do
  use ExUnit.Case
  alias Blockchain.Bloom

  @default_filter 364_236_115_780_354_413_527_177_740_824_718_248_475_191_169_123_433_179_704_674_083_584_030_171_707_548_895_141_763_338_864_017_157_468_044_931_245_187_476_551_639_917_006_481_686_358_559_826_056_819_612_140_499_456_696_964_058_447_681_377_941_080_842_953_023_782_344_796_365_486_712_958_202_642_967_905_678_562_795_813_182_653_349_819_408_730_761_190_197_772_532_753_708_011_416_878_102_770_310_284_058_867_224_260_870_159_690_230_717_337_345_574_083_724_951_534_664_321_152_788_810_106_636_281_468_311_475_567_122_070_065_682_554_961_594_780_791_945_980_493_299_780_947_753_165_983_844_578_885_074_727_735_505_366_654_109_046_841_451_940_478_976

  describe "EthBloom.create/1" do
    test "creates bloom filter" do
      filter = Bloom.create("rock")

      assert filter == @default_filter
    end
  end

  describe "EthBloom.add/2" do
    test "adds element to bloom filter" do
      new_filter = Bloom.add(@default_filter, "punk")

      assert Bloom.contains?(new_filter, "punk")
      assert Bloom.contains?(new_filter, "rock")
      refute Bloom.contains?(new_filter, "blues")
    end
  end
end
