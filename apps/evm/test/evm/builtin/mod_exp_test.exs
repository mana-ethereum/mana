defmodule EVM.Builtin.ModExpTest do
  use ExUnit.Case, async: true

  alias EVM.Builtin.ModExp

  # https://github.com/mana-ethereum/mana/issues/580
  test "calculates mod_exp (block #2_444_903, transaction #4 on ropsten)" do
    data =
      "0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000203790e561ff7d7641aacb12e01f997c551b256e2da3072a0348643316b63886933fffffffffffffffffffffffffffffffffffffffffffffffffffffffbfffff0cfffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f"
      |> Base.decode16!(case: :lower)

    available_gas = 1_000_000

    exec_env = %EVM.ExecEnv{data: data, config: EVM.Configuration.Byzantium.new()}
    {result_gas, _, _, output} = ModExp.exec(available_gas, exec_env)

    cost = available_gas - result_gas

    assert cost == 12_953

    assert output ==
             <<166, 77, 176, 208, 195, 39, 151, 52, 51, 231, 30, 237, 237, 72, 125, 118, 61, 235,
               159, 94, 12, 89, 197, 0, 244, 4, 188, 219, 122, 138, 212, 245>>
  end

  # https://github.com/mana-ethereum/mana/issues/687
  test "calculates mod_exp (block #4_177_929, transaction #73 on ropsten)" do
    data =
      "0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000007000000000000000000000000000000000000000000000000000000000000000f000000000000000000000000000000000000000000000000000000000000000b"
      |> Base.decode16!(case: :lower)

    available_gas = 1_000_000

    exec_env = %EVM.ExecEnv{data: data, config: EVM.Configuration.Byzantium.new()}
    {result_gas, _, _, output} = ModExp.exec(available_gas, exec_env)

    cost = available_gas - result_gas

    assert cost == 153

    assert output ==
             <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
               0, 0, 0, 10>>
  end

  # https://github.com/mana-ethereum/mana/issues/696
  test "calculated mod_exp (block #4_177_934)" do
    data =
      "00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000998c4052932635000000000000000000000000000000000000000000048a1b4aab9b9331498981000000000000000000000000000000000000000000000000000000000000000b"
      |> Base.decode16!(case: :lower)

    available_gas = 1_000_000

    exec_env = %EVM.ExecEnv{data: data, config: EVM.Configuration.Byzantium.new()}
    {result_gas, _, _, output} = ModExp.exec(available_gas, exec_env)

    cost = available_gas - result_gas

    assert cost == 4_198

    assert output ==
             <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
               0, 0, 0, 9>>
  end
end
