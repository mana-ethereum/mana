defmodule EVM.Operation.Sha3 do
 @doc """
  Compute Keccak-256 hash.


  ## Examples

      iex> EVM.Operation.Sha3.sha3([1, 0], %{machine_state: %EVM.MachineState{}})
      <<197, 210, 70, 1, 134, 247, 35, 60, 146, 126, 125, 178, 220, 199, 3, 192, 229, 0, 182, 83, 202, 130, 39, 59, 123, 250, 216, 4, 93, 133, 164, 112>>
  """
  @spec sha3(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def sha3([s0, s1], %{machine_state: machine_state}) do
    {value, _machine_state} = EVM.Memory.read(machine_state, s0, s1)

    :keccakf1600.sha3_256(value)
  end
end
