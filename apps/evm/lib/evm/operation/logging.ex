defmodule EVM.Operation.Logging do
  alias EVM.Operation

  @doc """
  Append log record with no topics.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Logging.log0([], %{stack: []})
      :unimplemented
  """
  @spec log0(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def log0(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Append log record with one topic.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Logging.log1([], %{stack: []})
      :unimplemented
  """
  @spec log1(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def log1(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Append log record with two topics.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Logging.log2([], %{stack: []})
      :unimplemented
  """
  @spec log2(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def log2(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Append log record with three topics.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Logging.log3([], %{stack: []})
      :unimplemented
  """
  @spec log3(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def log3(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Append log record with four topics.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Logging.log4([], %{stack: []})
      :unimplemented
  """
  @spec log4(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def log4(_args, %{stack: _stack}) do
    :unimplemented
  end
end
