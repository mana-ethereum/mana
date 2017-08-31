defmodule EVM.Operation.SHA3 do
 @doc """
  Compute Keccak-256 hash.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.Impl.sha3([], %{stack: []})
      :unimplemented
  """
  @spec sha3(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def sha3(_args, %{stack: _stack}) do
    :unimplemented
  end
end
