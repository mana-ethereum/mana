defmodule EVM.BuiltinTest do
  use ExUnit.Case, async: true
  doctest EVM.Builtin

  alias EVM.{Builtin, ExecEnv, Helpers}

  describe "ec_add/2" do
    test "calculates elliptic curve addition on bn128 curve" do
      gas = 10_000

      data =
        Helpers.left_pad_bytes(1, 32) <>
          Helpers.left_pad_bytes(2, 32) <>
          Helpers.left_pad_bytes(1, 32) <> Helpers.left_pad_bytes(2, 32)

      exec_env = %ExecEnv{config: EVM.Configuration.Byzantium.new(), data: data}

      {result_gas, _sub_state, _env, output} = Builtin.ec_add(gas, exec_env)

      x_result =
        1_368_015_179_489_954_701_390_400_359_078_579_693_043_519_447_331_113_978_918_064_868_415_326_638_035

      y_result =
        9_918_110_051_302_171_585_080_402_603_319_702_774_565_515_993_150_576_347_155_970_296_011_118_125_764

      expected_result =
        Helpers.left_pad_bytes(x_result, 32) <> Helpers.left_pad_bytes(y_result, 32)

      assert expected_result == output
      assert result_gas == 9_500
    end
  end

  describe "ec_mult/2" do
    test "multiplies point on elliptic curve bn 128" do
      gas = 50_000
      mult = 32
      x = 1
      y = 2

      data =
        Helpers.left_pad_bytes(x, 32) <>
          Helpers.left_pad_bytes(y, 32) <> Helpers.left_pad_bytes(mult, 32)

      exec_env = %ExecEnv{config: EVM.Configuration.Byzantium.new(), data: data}

      {result_gas, _sub_state, _env, output} = Builtin.ec_mult(gas, exec_env)

      x_result =
        4_873_079_524_557_847_867_653_965_550_062_716_553_062_346_862_158_697_560_012_111_398_864_356_025_363

      y_result =
        11_422_470_166_079_944_859_104_614_283_946_245_081_791_188_387_376_113_119_760_245_565_153_108_742_933

      expected_result =
        Helpers.left_pad_bytes(x_result, 32) <> Helpers.left_pad_bytes(y_result, 32)

      assert expected_result == output
      assert result_gas == 10_000
    end
  end
end
