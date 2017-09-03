defmodule EVM.Operation.Duplication do

  @doc """
  Duplicate stack item n-times.

  ## Examples

      iex> EVM.Operation.Duplication.dup_n(2, [5], %{})
      [5, 5]
  """
  @spec dup_n(integer(), Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def dup_n(n, [s0], _) do
    for _ <- 1..n, do: s0
  end
end
