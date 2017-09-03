defmodule EVM.Operation.StopAndArithmetic do
  alias EVM.Helpers
  alias EVM.Operation
  alias MathHelper
  use Bitwise

  @doc """
  Halts execution.

  In our implementation, this is a no-op.

  ## Examples

      iex> EVM.Operation.StopAndArithmetic.stop([], %{})
      :noop
  """
  @spec stop(Operation.stack_args, Operation.vm_map) :: Operation.noop
  def stop([], %{}) do
    :noop
  end

  @doc """
  Addition operation.

  Adds the values and wraps and encodes them

  ## Examples

      iex> EVM.Operation.StopAndArithmetic.add([1, 2], %{})
      3

      iex> EVM.Operation.StopAndArithmetic.add([-1, -5], %{})
      -6

      iex> EVM.Operation.StopAndArithmetic.add([0, 0], %{})
      0
  """
  @spec add(Operation.stack_args, Operation.vm_map) :: EVM.val
  def add([s0, s1], _), do: s0 + s1

  @doc """
  Multiplication operation.

  ## Examples

      iex> EVM.Operation.StopAndArithmetic.mul([5, 2], %{})
      10

      iex> EVM.Operation.StopAndArithmetic.mul([5, -2], %{})
      -10
  """
  @spec mul(Operation.stack_args, Operation.vm_map) :: EVM.val
  def mul([s0, s1], _), do: s0 * s1

  @doc """
  Subtraction operation.

  ## Examples

      iex> EVM.Operation.StopAndArithmetic.sub([5, 2], %{})
      3

      iex> EVM.Operation.StopAndArithmetic.sub([-1, 5], %{})
      -6
  """
  @spec sub(Operation.stack_args, Operation.vm_map) :: EVM.val
  def sub([s0, s1], _), do: s0 - s1

  @doc """
  Integer division operation.

  ## Examples

      iex> EVM.Operation.StopAndArithmetic.div([5, 2], %{})
      2

      iex> EVM.Operation.StopAndArithmetic.div([10, 2], %{})
      5

      iex> EVM.Operation.StopAndArithmetic.div([10, 0], %{})
      0
  """
  def div([_s0, 0], _), do: 0
  def div([s0, s1], _), do: Integer.floor_div(s0, s1)

  @doc """
  Signed integer division operation (truncated).
  """
  @spec sdiv(Operation.stack_args, Operation.vm_map) :: EVM.val
  def sdiv([s0, s1], _) do
    case Helpers.decode_signed(s1) do
      0 ->
          0
      1 ->
        s0
      -1 ->
        0 - Helpers.decode_signed(s0)
      _ ->
        MathHelper.round_int((Helpers.decode_signed(s0) / Helpers.decode_signed(s1)))
    end
  end

  @doc """
  Modulo remainder operation.
  """
  @spec mod(Operation.stack_args, Operation.vm_map) :: EVM.val
  def mod([s0, s1], _), do: if (s1 == 0), do: 0, else: rem(s0, s1)

  @doc """
  Signed modulo remainder operation.
  """
  @spec smod(Operation.stack_args, Operation.vm_map) :: EVM.val
  def smod([_, s1], _) when s1 == 0, do: 0
  def smod([s0, s1], _) do
    rem(Helpers.decode_signed(s0), Helpers.decode_signed(s1))
  end

  @doc """
  Modulo addition operation.
  """
  @spec addmod(Operation.stack_args, Operation.vm_map) :: EVM.val
  def addmod([_, _, s2], _) when s2 == 0, do: 0
  def addmod([s0, s1, s2], _), do: rem(s0 + s1, s2)

  @doc """
  Modulo multiplication operation.
  """
  @spec mulmod(Operation.stack_args, Operation.vm_map) :: EVM.val
  def mulmod([_, _, s2], _) when s2 == 0, do: 0
  def mulmod([s0, s1, s2], _), do: rem(s0 * s1, s2)

  @doc """
  Exponential operation

  ## Examples

      iex> EVM.Operation.StopAndArithmetic.exp([2, 3], %{})
      8
  """
  @spec exp(Operation.stack_args, Operation.vm_map) :: EVM.val
  def exp([s0, s1], _) do
    :crypto.mod_pow(s0, s1, EVM.max_int())
      |> :binary.decode_unsigned
  end

  @doc """
  Extend length of two’s complement signed integer.
  """
  @spec signextend(Operation.stack_args, Operation.vm_map) :: EVM.val
  def signextend([s0, s1], _) when s0 > 31, do: s1
  def signextend([s0, s1], _) do
    if (Helpers.bit_at(s1, Helpers.bit_position(s0)) == 1) do
      bor(s1, EVM.max_int() - (1 <<< Helpers.bit_position(s0)))
    else
      band(s1, ((1 <<< Helpers.bit_position(s0)) - 1))
    end
  end
end
