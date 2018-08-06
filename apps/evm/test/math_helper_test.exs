defmodule MathHelperTest do
  use ExUnit.Case
  doctest MathHelper

  describe "div/2" do
    test "divides large numbers" do
      num1 = 53_487_961_227_895_705_414_387_420_465_070_519_070_468_943_239
      num2 = 2_090_631_699
      result = 25_584_593_045_958_452_873_524_243_097_717_671_729

      assert MathHelper.div(num1, num2) == result
      refute num1 / num2 == result
    end
  end
end
