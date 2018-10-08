defmodule EVM.Builtin.ID do
  @g_identity_base 15
  @g_identity_byte 3

  @doc """
  Identity simply returnes the output as the input

  ## Examples

      iex> EVM.Builtin.ID.exec(3000,  %EVM.ExecEnv{data: <<1, 2, 3>>})
      {2982, %EVM.SubState{}, %EVM.ExecEnv{data: <<1, 2, 3>>},  <<1, 2, 3>>}
  """

  @spec exec(EVM.Gas.t(), EVM.ExecEnv.t()) ::
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()}
  def exec(gas, exec_env) do
    data = exec_env.data
    required_gas = @g_identity_base + @g_identity_byte * MathHelper.bits_to_words(byte_size(data))

    if required_gas <= gas do
      remaining_gas = gas - required_gas

      {remaining_gas, %EVM.SubState{}, exec_env, data}
    else
      {0, %EVM.SubState{}, exec_env, :failed}
    end
  end
end
