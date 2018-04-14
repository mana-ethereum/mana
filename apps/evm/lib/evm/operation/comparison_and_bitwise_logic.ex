defmodule EVM.Operation.ComparisonAndBitwiseLogic do
  alias MathHelper
  alias EVM.Helpers
  alias EVM.Operation
  use Bitwise

  @doc """
  Less-than comparision.

  ## Examples

      iex> EVM.Operation.ComparisonAndBitwiseLogic.lt([55, 66], %{})
      1

      iex> EVM.Operation.ComparisonAndBitwiseLogic.lt([66, 55], %{})
      0

      iex> EVM.Operation.ComparisonAndBitwiseLogic.lt([55, 55], %{})
      0
  """
  @spec lt(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def lt([s0, s1], _), do: if(s0 < s1, do: 1, else: 0)

  @doc """
  Greater-than comparision.

  ## Examples

      iex> EVM.Operation.ComparisonAndBitwiseLogic.gt([55, 66], %{})
      0

      iex> EVM.Operation.ComparisonAndBitwiseLogic.gt([66, 55], %{})
      1

      iex> EVM.Operation.ComparisonAndBitwiseLogic.gt([55, 55], %{})
      0
  """
  @spec gt(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def gt([s0, s1], _), do: if(s0 > s1, do: 1, else: 0)

  @doc """
  Signed less-than comparision.

  ## Examples

      iex> EVM.Operation.ComparisonAndBitwiseLogic.slt([EVM.Helpers.encode_signed(-55), 55], %{})
      1

      iex> EVM.Operation.ComparisonAndBitwiseLogic.slt([66, EVM.Helpers.encode_signed(-55)], %{})
      0

      iex> EVM.Operation.ComparisonAndBitwiseLogic.slt([55, 55], %{})
      0
  """
  @spec slt(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def slt([s0, s1], _) do
    if Helpers.decode_signed(s0) < Helpers.decode_signed(s1) do
      1
    else
      0
    end
  end

  @doc """
  Signed greater-than comparision

  ## Examples

      iex> EVM.Operation.ComparisonAndBitwiseLogic.sgt([EVM.Helpers.encode_signed(-55), 55], %{})
      0

      iex> EVM.Operation.ComparisonAndBitwiseLogic.sgt([66, EVM.Helpers.encode_signed(-55)], %{})
      1

      iex> EVM.Operation.ComparisonAndBitwiseLogic.sgt([55, 55], %{})
      0
  """
  @spec sgt(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def sgt([s0, s1], _) do
    if Helpers.decode_signed(s0) > Helpers.decode_signed(s1) do
      1
    else
      0
    end
  end

  @doc """
  Equality comparision.

  ## Examples

      iex> EVM.Operation.ComparisonAndBitwiseLogic.eq([55, 1], %{})
      0

      iex> EVM.Operation.ComparisonAndBitwiseLogic.eq([55, 55], %{})
      1

      iex> EVM.Operation.ComparisonAndBitwiseLogic.eq([0, 0], %{})
      1
  """
  @spec eq(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def eq([s0, s1], _), do: if(s0 == s1, do: 1, else: 0)

  @doc """
  Simple not operator.

  ## Examples

      iex> EVM.Operation.ComparisonAndBitwiseLogic.iszero([0], %{})
      1

      iex> EVM.Operation.ComparisonAndBitwiseLogic.iszero([1], %{})
      0
  """
  @spec iszero(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def iszero([s0], _vm_map), do: if(s0 == 0, do: 1, else: 0)

  @doc """
  Bitwise AND operation.

  ## Examples

      iex> EVM.Operation.ComparisonAndBitwiseLogic.and_([1, 1], %{})
      1

      iex> EVM.Operation.ComparisonAndBitwiseLogic.and_([1, 0], %{})
      0
  """
  @spec and_(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def and_([s0, s1], _vm_map), do: band(s0, s1)

  @doc """
  Bitwise OR operation.

  ## Examples

      iex> EVM.Operation.ComparisonAndBitwiseLogic.or_([1, 1], %{})
      1

      iex> EVM.Operation.ComparisonAndBitwiseLogic.or_([1, 0], %{})
      1

      iex> EVM.Operation.ComparisonAndBitwiseLogic.or_([0, 0], %{})
      0
  """
  @spec or_(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def or_([s0, s1], _vm_map), do: bor(s0, s1)

  @doc """
  Bitwise XOR operation.

  ## Examples

      iex> EVM.Operation.ComparisonAndBitwiseLogic.xor_([1, 1], %{})
      0

      iex> EVM.Operation.ComparisonAndBitwiseLogic.or_([1, 0], %{})
      1
  """
  @spec xor_(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def xor_([s0, s1], _vm_map), do: bxor(s0, s1)

  @doc """
  Bitwise NOT operation.
  ## Examples

      iex> EVM.Operation.ComparisonAndBitwiseLogic.not_([1], %{})
      -2

  """
  @spec not_(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def not_([s0], _), do: bnot(s0)

  @doc """
  Retrieve single byte from word.

  ## Examples

      iex> EVM.Operation.ComparisonAndBitwiseLogic.byte([31, 1], %{})
      1
  """
  @spec byte(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def byte([s0, s1], _vm_map) do
    if s0 < EVM.word_size() do
      :binary.at(Helpers.left_pad_bytes(s1, 32), s0)
    else
      0
    end
  end
end
