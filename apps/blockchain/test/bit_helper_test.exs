defmodule BitHelperTest do
  use ExUnit.Case, async: true
  doctest BitHelper

  describe "pad/3" do
    test "pads binary left with 0 to desired length" do
      assert <<0, 0, 0, 0, 9>> == BitHelper.pad(<<9>>, 5)
    end

    test "pads binary right when little-endian is specified" do
      big_endian = <<2, 9>>
      little_endian = <<9, 2>>

      assert <<0, 0, 2, 9>> == BitHelper.pad(big_endian, 4, :big)
      assert <<9, 2, 0, 0>> == BitHelper.pad(little_endian, 4, :little)
    end
  end
end
