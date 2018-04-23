defmodule EVM.Operation.Duplication do
  alias EVM.Operation

  @doc """
  Duplicate stack item n-times.

  ## Examples

      iex> EVM.Operation.Duplication.dup([1, 2, 3], %{})
      [3, 1, 2, 3]
  """
  @spec dup(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def dup(list = [head | _], check) do
    last = List.last(list)

    [last | list]
  end
end
