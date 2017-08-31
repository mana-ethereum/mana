defmodule EVM.Operation.Exchange do
  alias EVM.Stack
  alias EVM.MachineState

  @doc """
  Exchange 1st and 2nd stack items.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Impl.swap1([1,2], %{stack: []})
      %{stack: [2,1]}
  """
  @spec swap1(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def swap1([s0, s1], %{stack: stack}) do
    stack |> push(s0) |> Map.get(:stack) |> push(s1)
  end

  @doc """
  Exchange 2nd and 3rd stack items.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Impl.swap2([], %{stack: []})
      :unimplemented
  """
  @spec swap2(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def swap2(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Exchange 3rd and 4th stack items.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Impl.swap3([], %{stack: []})
      :unimplemented
  """
  @spec swap3(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def swap3(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Exchange 4th and 5th stack items.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Impl.swap4([], %{stack: []})
      :unimplemented
  """
  @spec swap4(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def swap4(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Exchange 5th and 6th stack items.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Impl.swap5([], %{stack: []})
      :unimplemented
  """
  @spec swap5(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def swap5(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Exchange 6th and 7th stack items.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Impl.swap6([], %{stack: []})
      :unimplemented
  """
  @spec swap6(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def swap6(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Exchange 7th and 8th stack items.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Impl.swap7([], %{stack: []})
      :unimplemented
  """
  @spec swap7(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def swap7(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Exchange 8th and 9th stack items.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Impl.swap8([], %{stack: []})
      :unimplemented
  """
  @spec swap8(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def swap8(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Exchange 9th and 10th stack items.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Impl.swap9([], %{stack: []})
      :unimplemented
  """
  @spec swap9(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def swap9(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Exchange 10th and 11th stack items.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Impl.swap10([], %{stack: []})
      :unimplemented
  """
  @spec swap10(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def swap10(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Exchange 11th and 12th stack items.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Impl.swap11([], %{stack: []})
      :unimplemented
  """
  @spec swap11(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def swap11(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Exchange 12th and 13th stack items.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Impl.swap12([], %{stack: []})
      :unimplemented
  """
  @spec swap12(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def swap12(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Exchange 13th and 14th stack items.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Impl.swap13([], %{stack: []})
      :unimplemented
  """
  @spec swap13(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def swap13(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Exchange 14th and 15th stack items.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Impl.swap14([], %{stack: []})
      :unimplemented
  """
  @spec swap14(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def swap14(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Exchange 15th and 16th stack items.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Impl.swap15([], %{stack: []})
      :unimplemented
  """
  @spec swap15(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def swap15(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Exchange 16th and 17th stack items.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Impl.swap16([], %{stack: []})
      :unimplemented
  """
  @spec swap16(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def swap16(_args, %{stack: _stack}) do
    :unimplemented
  end

  # Helper function to push to the stack within machine_state.
  @spec push(MachineState.t | Stack.t, EVM.val) :: Operation.op_result
  defp push(machine_state=%MachineState{}, val) do
    %{
      machine_state |
      stack: machine_state.stack
        |> Stack.push(val)
    }
  end

  # Helper function to just return an updated stack
  defp push(stack, val) when is_list(stack) do
    %{stack: Stack.push(stack, val)}
  end
end
