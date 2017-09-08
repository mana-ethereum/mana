defmodule EVM.Operation.Duplication do

  @doc """
  Duplicate stack item n-times.

  ## Examples

      iex> EVM.Operation.Duplication.dup([1, 2, 3], %{})
      [3, 2, 1, 1]
  """
  @spec dup(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def dup(list = [ head | _ ], _) do
    :lists.reverse([head | list])
  end
end
