defmodule EVM.Operation.Sha3 do
  alias EVM.Stack
  alias EVM.Helpers

  @doc """
  Compute Keccak-256 hash.


  ## Examples

      iex> EVM.Operation.Sha3.sha3([1, 0], %{machine_state: %EVM.MachineState{}})
      %EVM.MachineState{active_words: 0, gas: nil, memory: "", program_counter: 0, previously_active_words: 0, stack: [89477152217924674838424037953991966239322087453347756267410168184682657981552]}
  """
  @spec sha3(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def sha3([s0, s1], %{machine_state: machine_state}) do
    {value, machine_state} = EVM.Memory.read(machine_state, s0, s1)

    hash = Helpers.encode_val(:keccakf1600.sha3_256(value))

    %{machine_state | stack: Stack.push(machine_state.stack, hash)}
  end
end
