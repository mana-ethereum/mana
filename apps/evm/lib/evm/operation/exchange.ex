defmodule EVM.Operation.Exchange do
  @doc """
  Swaps the first and last values on the stack.

  ## Examples

      iex> EVM.Operation.Exchange.swap([1, 2, 3], %{})
      [3, 2, 1]
      iex> EVM.Operation.Exchange.swap([1, 2, 3, 4, 5, 6], %{})
      [6, 2, 3, 4, 5, 1]
  """
  @spec swap(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def swap([first | rest], _vm_map) do
    [last | middle] = :lists.reverse(rest)
    [last | :lists.reverse([first | middle])]
  end
end
