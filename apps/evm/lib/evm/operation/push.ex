defmodule EVM.Operation.Push do
  @doc """
  Place n-byte item on stack

  ## Examples

      iex> EVM.Operation.Push.push_n(1, [], %{machine_state: %EVM.MachineState{stack: [], pc: 1}, exec_env: %EVM.ExecEnv{machine_code: <<0x10, 0x11, 0x12, 0x13>>}})
      0x12

      iex> EVM.Operation.Push.push_n(1, [], %{machine_state: %EVM.MachineState{stack: [], pc: 2}, exec_env: %EVM.ExecEnv{machine_code: <<0x10, 0x11, 0x12, 0x13>>}})
      0x13

      iex> EVM.Operation.Push.push_n(1, [], %{machine_state: %EVM.MachineState{stack: [], pc: 3}, exec_env: %EVM.ExecEnv{machine_code: <<0x10, 0x11, 0x12, 0x13>>}})
      0x00

      iex> EVM.Operation.Push.push_n(1, [], %{machine_state: %EVM.MachineState{stack: [], pc: 4}, exec_env: %EVM.ExecEnv{machine_code: <<0x10, 0x11, 0x12, 0x13>>}})
      0x00

      iex> EVM.Operation.Push.push_n(1, [], %{machine_state: %EVM.MachineState{stack: [], pc: 100}, exec_env: %EVM.ExecEnv{machine_code: <<0x10, 0x11, 0x12, 0x13>>}})
      0x00

      iex> EVM.Operation.Push.push_n(6, [], %{machine_state: %EVM.MachineState{stack: [], pc: 0}, exec_env: %EVM.ExecEnv{machine_code: <<0xFF, 0x10, 0x11, 0x12, 0x13>>}})
      17665503723520

      iex> EVM.Operation.Push.push_n(16, [], %{machine_state: %EVM.MachineState{stack: [], pc: 100}, exec_env: %EVM.ExecEnv{machine_code: <<0x10, 0x11, 0x12, 0x13>>}})
      0x00
  """
  @spec push_n(integer(), Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def push_n(n, [], %{machine_state: machine_state, exec_env: exec_env}) do
    val = EVM.Memory.read_zeroed_memory(exec_env.machine_code, machine_state.pc + 1, n) |> :binary.decode_unsigned

    val
  end
end
