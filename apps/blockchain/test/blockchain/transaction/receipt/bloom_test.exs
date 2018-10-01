defmodule Blockchain.Transaction.Receipt.BloomTest do
  use ExUnit.Case
  alias Blockchain.Transaction.Receipt.Bloom

  describe "contains?/2" do
    test "checks if value is in filter" do
      new_filter = Bloom.empty()
      rock_filter = "rock" |> Bloom.new() |> Bloom.merge(new_filter)

      assert Bloom.contains?(rock_filter, "rock")
      refute Bloom.contains?(rock_filter, "punk")
    end
  end

  describe "log_entry_bloom/1" do
    test "calculates bloom filter of the log entry" do
      log_entry = %EVM.LogEntry{
        address:
          <<13, 207, 65, 208, 147, 66, 139, 9, 108, 165, 1, 167, 205, 26, 116, 8, 85, 167, 151,
            111>>,
        data:
          <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0>>,
        topics: [
          <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            4, 12, 174>>
        ]
      }

      bloom =
        log_entry
        |> Bloom.log_entry_bloom()
        |> :binary.list_to_bin()
        |> :binary.decode_unsigned()

      # credo:disable-for-lines:5
      expected_bloom =
        73_163_108_942_571_733_361_052_448_588_893_064_672_990_928_033_389_433_452_969_840_109_294_805_313_802_464_776_599_652_072_787_989_947_509_722_109_919_889_952_270_524_882_118_408_455_965_444_940_320_026_742_494_913_199_208_746_736_125_187_840_435_050_982_219_880_083_307_391_497_000_678_529_786_207_937_494_704_366_280_639_151_307_704_660_002_880_013_603_298_806_315_727_360_601_877_413_348_680_310_729_213_970_218_176_705_221_536_816_209_397_180_701_261_421_045_226_395_014_516_354_551_672_430_576_807_091_091_425_140_127_579_724_060_732_353_682_652_891_092_009_083_382_100_500_762_665_146_513_284_386_898_167_578_526_442_609_858_576_097_289_816_449_711_962_716_786_572_424_704_535_768_704_239_356_953_819_615_614_040_276_992

      assert bloom == expected_bloom
    end
  end
end
