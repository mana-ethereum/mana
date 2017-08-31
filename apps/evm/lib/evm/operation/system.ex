defmodule EVM.Operation.System do
  alias EVM.MachineState
  @doc """
  Create a new account with associated code.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Impl.create([], %{stack: []})
      :unimplemented
  """
  @spec create(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def create(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Message-call into an account.,

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Impl.call([], %{stack: []})
      :unimplemented
  """
  @spec call(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def call(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Message-call into this account with an alternative account’s code.,

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Impl.callcode([], %{stack: []})
      :unimplemented
  """
  @spec callcode(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def callcode(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Halt execution returning output data,

  ## Examples

      iex> EVM.Operation.Impl.return([5, 33], %{machine_state: %EVM.MachineState{active_words: 0}})
      %EVM.MachineState{active_words: 2}

      iex> EVM.Operation.Impl.return([5, 33], %{machine_state: %EVM.MachineState{active_words: 5}})
      %EVM.MachineState{active_words: 5}
  """
  @spec return(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def return([_mem_start, mem_end], %{machine_state: machine_state}) do
    # We may have to bump up number of active words
    machine_state |> MachineState.maybe_set_active_words(EVM.Memory.get_active_words(mem_end))
  end

  @doc """
  Message-call into this account with an alternative account’s code, but persisting the current values for sender and value.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Impl.delegatecall([], %{stack: []})
      :unimplemented
  """
  @spec delegatecall(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def delegatecall(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Halt execution and register account for later deletion.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Impl.suicide([], %{stack: []})
      :unimplemented
  """
  @spec suicide(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def suicide(_args, %{stack: _stack}) do
    :unimplemented
  end
end
