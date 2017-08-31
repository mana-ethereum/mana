defmodule EVM.Operation.ComparisonAndBitwiseLogic do
  alias MathHelper
  use Bitwise

  @doc """
  Less-than comparision.

  ## Examples

      iex> EVM.Operation.Impl.lt([55, 66], %{})
      1

      iex> EVM.Operation.Impl.lt([66, 55], %{})
      0

      iex> EVM.Operation.Impl.lt([55, 55], %{})
      0
  """
  @spec lt(Operation.stack_args, Operation.vm_map) :: Operation.Operation.op_result
  def lt([s0, s1], _), do: if s0 < s1, do: 1, else: 0

  @doc """
  Greater-than comparision.

  ## Examples

      iex> EVM.Operation.Impl.gt([55, 66], %{})
      0

      iex> EVM.Operation.Impl.gt([66, 55], %{})
      1

      iex> EVM.Operation.Impl.gt([55, 55], %{})
      0
  """
  @spec gt(Operation.stack_args, Operation.vm_map) :: Operation.Operation.op_result
  def gt([s0, s1], _), do: if s0 > s1, do: 1, else: 0

  @doc """
  Signed less-than comparision.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Impl.slt([], %{stack: []})
      :unimplemented
  """
  @spec slt(Operation.stack_args, Operation.vm_map) :: Operation.Operation.op_result
  def slt(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Signed greater-than comparision

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Impl.sgt([], %{stack: []})
      :unimplemented
  """
  @spec sgt(Operation.stack_args, Operation.vm_map) :: Operation.Operation.op_result
  def sgt(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Equality comparision.

  ## Examples

      iex> EVM.Operation.Impl.eq([55, 1], %{stack: []})
      %{stack: [0]}

      iex> EVM.Operation.Impl.eq([55, 55], %{stack: []})
      %{stack: [1]}

      iex> EVM.Operation.Impl.eq([0, 0], %{stack: []})
      %{stack: [1]}
  """
  @spec eq(Operation.stack_args, Operation.vm_map) :: Operation.Operation.op_result
  def eq([s0, s1], _), do: if s0 == s1, do: 1, else: 0

  @doc """
  Simple not operator.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Impl.iszero([], %{stack: []})
      :unimplemented
  """
  @spec iszero(Operation.stack_args, Operation.vm_map) :: Operation.Operation.op_result
  def iszero(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Bitwise AND operation.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Impl.and_([], %{stack: []})
      :unimplemented
  """
  @spec and_(Operation.stack_args, Operation.vm_map) :: Operation.Operation.op_result
  def and_(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Bitwise OR operation.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Impl.or_([], %{stack: []})
      :unimplemented
  """
  @spec or_(Operation.stack_args, Operation.vm_map) :: Operation.Operation.op_result
  def or_(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Bitwise XOR operation.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Impl.xor_([], %{stack: []})
      :unimplemented
  """
  @spec xor_(Operation.stack_args, Operation.vm_map) :: Operation.Operation.op_result
  def xor_(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Bitwise NOT operation.
  """
  @spec not_(Operation.stack_args, Operation.vm_map) :: Operation.Operation.op_result
  def not_([s0], _), do: bnot(s0)

  @doc """
  Retrieve single byte from word.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Impl.byte([], %{stack: []})
      :unimplemented
  """
  @spec byte(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def byte(_args, %{stack: _stack}) do
    :unimplemented
  end
end
