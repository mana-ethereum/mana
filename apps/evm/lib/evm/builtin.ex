defmodule EVM.Builtin do
  @moduledoc """
  Implements the built-in functions as defined in Appendix E
  of the Yellow Paper. These are contract functions that
  natively exist in Ethereum.

  TODO: Implement and add doc tests.
  """

  @g_sha256 60 + 12
  @g_identity_base 15
  @g_identity_byte 3

  @spec run_ecrec(EVM.Gas.t(), EVM.ExecEnv.t()) ::
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()}
  def run_ecrec(gas, exec_env), do: {gas, %EVM.SubState{}, exec_env, <<>>}

  @doc """
  Runs SHA256 hashing

  ## Examples

      iex> EVM.Builtin.run_sha256(3000,  %EVM.ExecEnv{data: <<1, 2, 3>>})
      {2928, %EVM.SubState{}, %EVM.ExecEnv{data: <<1, 2, 3>>}, <<3, 144, 88, 198,
        242, 192, 203, 73, 44, 83, 59, 10, 77, 20, 239,119, 204, 15, 120, 171, 204,
        206, 213, 40, 125, 132, 161, 162, 1, 28, 251, 129>>}
  """
  @spec run_sha256(EVM.Gas.t(), EVM.ExecEnv.t()) ::
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()}
  def run_sha256(gas, exec_env = %EVM.ExecEnv{data: data}) do
    used_gas = @g_sha256 * MathHelper.bits_to_words(byte_size(data))

    if(used_gas < gas) do
      remaining_gas = gas - used_gas
      result = :crypto.hash(:sha256, data)
      {remaining_gas, %EVM.SubState{}, exec_env, result}
    else
      {gas, %EVM.SubState{}, exec_env, <<>>}
    end
  end

  @spec run_rip160(EVM.Gas.t(), EVM.ExecEnv.t()) ::
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()}
  def run_rip160(gas, exec_env), do: {gas, %EVM.SubState{}, exec_env, <<>>}

  @doc """
  Identity simply returnes the output as the input

  ## Examples

      iex> EVM.Builtin.run_id(3000,  %EVM.ExecEnv{data: <<1, 2, 3>>})
      {2982, %EVM.SubState{}, %EVM.ExecEnv{data: <<1, 2, 3>>},  <<1, 2, 3>>}
  """

  @spec run_id(EVM.Gas.t(), EVM.ExecEnv.t()) ::
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()}
  def run_id(gas, exec_env) do
    data = exec_env.data
    used_gas = @g_identity_base + @g_identity_byte * MathHelper.bits_to_words(byte_size(data))

    if(used_gas < gas) do
      remaining_gas = gas - used_gas
      {remaining_gas, %EVM.SubState{}, exec_env, data}
    else
      {gas, %EVM.SubState{}, exec_env, <<>>}
    end
  end
end
