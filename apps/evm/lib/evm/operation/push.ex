defmodule EVM.Operation.Push do
  @doc """
  Place n-byte item on stack

  ## Examples

      iex> EVM.Operation.Push.push_n(1, [], %{machine_state: %EVM.MachineState{stack: [], program_counter: 1}, exec_env: %EVM.ExecEnv{machine_code: <<0x10, 0x11, 0x12, 0x13>>}})
      0x12

      iex> EVM.Operation.Push.push_n(1, [], %{machine_state: %EVM.MachineState{stack: [], program_counter: 2}, exec_env: %EVM.ExecEnv{machine_code: <<0x10, 0x11, 0x12, 0x13>>}})
      0x13

      iex> EVM.Operation.Push.push_n(1, [], %{machine_state: %EVM.MachineState{stack: [], program_counter: 3}, exec_env: %EVM.ExecEnv{machine_code: <<0x10, 0x11, 0x12, 0x13>>}})
      0x00

      iex> EVM.Operation.Push.push_n(1, [], %{machine_state: %EVM.MachineState{stack: [], program_counter: 4}, exec_env: %EVM.ExecEnv{machine_code: <<0x10, 0x11, 0x12, 0x13>>}})
      0x00

      iex> EVM.Operation.Push.push_n(1, [], %{machine_state: %EVM.MachineState{stack: [], program_counter: 100}, exec_env: %EVM.ExecEnv{machine_code: <<0x10, 0x11, 0x12, 0x13>>}})
      0x00

      iex> EVM.Operation.Push.push_n(6, [], %{machine_state: %EVM.MachineState{stack: [], program_counter: 0}, exec_env: %EVM.ExecEnv{machine_code: <<0xFF, 0x10, 0x11, 0x12, 0x13>>}})
      17665503723520

      iex> EVM.Operation.Push.push_n(16, [], %{machine_state: %EVM.MachineState{stack: [], program_counter: 100}, exec_env: %EVM.ExecEnv{machine_code: <<0x10, 0x11, 0x12, 0x13>>}})
      0x00
  """
  @spec push_n(integer(), Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def push_n(n, _args, %{machine_state: machine_state, exec_env: %{machine_code: machine_code}}) do
    EVM.Memory.read_zeroed_memory(machine_code, machine_state.program_counter + 1, n)
      |> :binary.decode_unsigned
  end
end
