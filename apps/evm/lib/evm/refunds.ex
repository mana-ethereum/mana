defmodule EVM.Refunds do
  @type t :: EVM.val()
  alias EVM.{
    MachineState,
    ExecEnv,
    MachineCode,
    Operation
  }
  # Refund given (added into refund counter) when the storage value is set to zero from non-zero.
  @g_sclear 15000
  # Refund given (added into refund counter) for suiciding an account.
  @g_suicide 24000

  @doc """
  Returns the refund amount given a cycle of the VM.

  ## Examples

      iex> account_interface = EVM.Interface.Mock.MockAccountInterface.new()
      iex> machine_code = <<EVM.Operation.metadata(:sstore).id>>
      iex> exec_env = %EVM.ExecEnv{
      ...>  account_interface: account_interface,
      ...>  machine_code: machine_code,
      ...> } |> EVM.ExecEnv.put_storage(5,4)
      iex> machine_state = %EVM.MachineState{stack: [5 , 0]}
      iex> sub_state = %EVM.SubState{}
      iex> EVM.Refunds.refund(machine_state, sub_state, exec_env)
      15000
  """
  @spec refund(MachineState.t(), SubState.t(), ExecEnv.t()) :: t | nil
  def refund(machine_state, sub_state, exec_env) do
    operation = MachineCode.current_operation(machine_state, exec_env)
    inputs = Operation.inputs(operation, machine_state)
    refund(operation.sym, inputs, machine_state, sub_state, exec_env) || 0
  end

  @doc """
  SUCICIDE operations produce a refund if the address has not already been suicided.

  ## Examples

      iex> address = 0x0000000000000000000000000000000000000001
      iex> machine_code = <<EVM.Operation.metadata(:sstore).id>>
      iex> exec_env = %EVM.ExecEnv{
      ...>   address: address,
      ...>   machine_code: machine_code,
      ...> }
      iex> machine_state = %EVM.MachineState{}
      iex> sub_state = %EVM.SubState{}
      iex> EVM.Refunds.refund(:suicide, [], machine_state, sub_state, exec_env)
      24000

      iex> account_interface = EVM.Interface.Mock.MockAccountInterface.new()
      iex> machine_code = <<EVM.Operation.metadata(:sstore).id>>
      iex> exec_env = %EVM.ExecEnv{
      ...>  account_interface: account_interface,
      ...>  machine_code: machine_code,
      ...> } |> EVM.ExecEnv.put_storage(5,4)
      iex> machine_state = %EVM.MachineState{}
      iex> sub_state = %EVM.SubState{}
      iex> EVM.Refunds.refund(:sstore, [5, 0], machine_state, sub_state, exec_env)
      15000
  """

  def refund(:suicide, _args, _machine_state, sub_state, exec_env) do
    if exec_env.address not in sub_state.suicide_list do
      @g_suicide
    end
  end


  # SSTORE operations produce a refund when storage is set to zero from some non-zero value.
  def refund(:sstore, [key, new_value], _machine_state, _sub_state, exec_env) do
    old_value = ExecEnv.get_storage(exec_env, key)
    if new_value == 0 && (old_value not in [:account_not_found, :key_not_found]) do
      @g_sclear
    end
  end

  def refund(_opcode, _stack, _machine_state, _sub_state, _exec_env), do: nil
end
