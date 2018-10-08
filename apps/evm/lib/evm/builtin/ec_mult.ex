defmodule EVM.Builtin.EcMult do
  alias EVM.{Memory, Helpers}
  alias BN.{BN128Arithmetic, FQ}

  @g_ec_mult 40_000

  @doc """
  Elliptic curve multiplication
  """
  @spec exec(EVM.Gas.t(), EVM.ExecEnv.t()) ::
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()}
  def exec(gas, exec_env) do
    data = Memory.read_zeroed_memory(exec_env.data, 0, 96)

    <<x_bin::binary-size(32), y_bin::binary-size(32), scalar_bin::binary-size(32)>> = data

    x = :binary.decode_unsigned(x_bin)
    y = :binary.decode_unsigned(y_bin)
    scalar = :binary.decode_unsigned(scalar_bin)

    cond do
      gas < @g_ec_mult ->
        {0, %EVM.SubState{}, exec_env, :failed}

      x > FQ.default_modulus() || y > FQ.default_modulus() ->
        {0, %EVM.SubState{}, exec_env, :failed}

      true ->
        calculate_ec_mult({x, y}, scalar, gas, exec_env)
    end
  end

  @spec calculate_ec_mult({integer, integer}, integer, EVM.Gas.t(), EVM.ExecEnv.t()) ::
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()}
  defp calculate_ec_mult({x, y}, scalar, gas, exec_env) do
    point = {FQ.new(x), FQ.new(y)}

    if BN128Arithmetic.on_curve?(point) do
      {:ok, {result_x, result_y}} = BN128Arithmetic.mult(point, scalar)

      result_x = :binary.encode_unsigned(result_x.value)
      result_y = :binary.encode_unsigned(result_y.value)

      output = Helpers.left_pad_bytes(result_x, 32) <> Helpers.left_pad_bytes(result_y, 32)

      {gas - @g_ec_mult, %EVM.SubState{}, exec_env, output}
    else
      {0, %EVM.SubState{}, exec_env, :failed}
    end
  end
end
