defmodule EVM.Builtin.Rip160 do
  @g_rip160_base 600
  @g_rip160_byte 120
  @contract_address <<3::160>>

  @doc """
  Runs RIPEMD160 hashing

  ## Examples

      iex> EVM.Builtin.Rip160.exec(3000,  %EVM.ExecEnv{data: <<1, 2, 3>>})
      {2280, %EVM.SubState{}, %EVM.ExecEnv{data: <<1, 2, 3>>},<<0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 121, 249, 1, 218, 38, 9, 240, 32, 173, 173, 191, 46, 95,
        104, 161, 108, 140, 63, 125, 87>>}
  """
  @spec exec(EVM.Gas.t(), EVM.ExecEnv.t()) ::
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()}
  def exec(gas, exec_env = %EVM.ExecEnv{data: data}) do
    required_gas = @g_rip160_base + @g_rip160_byte * MathHelper.bits_to_words(byte_size(data))

    if required_gas <= gas do
      remaining_gas = gas - required_gas
      result = :crypto.hash(:ripemd160, data) |> EVM.Helpers.left_pad_bytes(32)
      {remaining_gas, %EVM.SubState{}, exec_env, result}
    else
      {0, %EVM.SubState{}, exec_env, :failed}
    end
  end

  def contract_address do
    @contract_address
  end
end
