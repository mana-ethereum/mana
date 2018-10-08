defmodule EVM.Builtin.EcAdd do
  alias EVM.{Memory, Helpers}
  alias BN.{FQ, BN128Arithmetic}

  @g_ec_add 500

  @doc """
  Elliptic curve addition
  """
  @spec exec(EVM.Gas.t(), EVM.ExecEnv.t()) ::
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()}
  def exec(gas, exec_env) do
    data = Memory.read_zeroed_memory(exec_env.data, 0, 128)

    <<x1_bin::binary-size(32), y1_bin::binary-size(32), x2_bin::binary-size(32),
      y2_bin::binary-size(32)>> = data

    x1 = :binary.decode_unsigned(x1_bin)
    y1 = :binary.decode_unsigned(y1_bin)
    x2 = :binary.decode_unsigned(x2_bin)
    y2 = :binary.decode_unsigned(y2_bin)

    cond do
      gas < @g_ec_add ->
        {0, %EVM.SubState{}, exec_env, :failed}

      x1 > FQ.default_modulus() || x2 > FQ.default_modulus() || y1 > FQ.default_modulus() ||
          y2 > FQ.default_modulus() ->
        {0, %EVM.SubState{}, exec_env, :failed}

      true ->
        calculate_ec_add({x1, y1}, {x2, y2}, gas, exec_env)
    end
  end

  @spec calculate_ec_add({integer, integer}, {integer, integer}, EVM.Gas.t(), EVM.ExecEnv.t()) ::
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()}
  defp calculate_ec_add({x1, y1}, {x2, y2}, gas, exec_env) do
    point1 = {FQ.new(x1), FQ.new(y1)}
    point2 = {FQ.new(x2), FQ.new(y2)}

    if !BN128Arithmetic.on_curve?(point1) || !BN128Arithmetic.on_curve?(point2) do
      {0, %EVM.SubState{}, exec_env, :failed}
    else
      {:ok, {result_x, result_y}} = BN128Arithmetic.add(point1, point2)

      result_x = :binary.encode_unsigned(result_x.value)
      result_y = :binary.encode_unsigned(result_y.value)

      output = Helpers.left_pad_bytes(result_x, 32) <> Helpers.left_pad_bytes(result_y, 32)

      {gas - @g_ec_add, %EVM.SubState{}, exec_env, output}
    end
  end
end
