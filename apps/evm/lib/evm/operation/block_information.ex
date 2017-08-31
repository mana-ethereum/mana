defmodule EVM.Operation.BlockInformation do
  alias EVM.Operation
  @doc """
  Get the hash of one of the 256 most recent complete blocks

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Impl.blockhash([], %{stack: []})
      :unimplemented
  """
  @spec blockhash(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def blockhash(_args, %{stack: _stack}) do
    # TODO: from header of block and ... ?
    :unimplemented
  end

  @doc """
  Get the block’s beneficiary address

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Impl.coinbase([], %{stack: []})
      :unimplemented
  """
  @spec coinbase(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def coinbase(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Get the block’s timestamp

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Impl.timestamp([], %{stack: []})
      :unimplemented
  """
  @spec timestamp(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def timestamp(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Get the block’s number.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Impl.number([], %{stack: []})
      :unimplemented
  """
  @spec number(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def number(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Get the block’s difficulty.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Impl.difficulty([], %{stack: []})
      :unimplemented
  """
  @spec difficulty(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def difficulty(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Get the block’s gas limit.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Impl.gaslimit([], %{stack: []})
      :unimplemented
  """
  @spec gaslimit(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def gaslimit(_args, %{stack: _stack}) do
    :unimplemented
  end

end
