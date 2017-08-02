defmodule EVM.Instruction.Memory do
  @moduledoc """
  When calling instructions, we may adjust the number
  of active words in the machine state. These functions
  provide a simple way to determine the number of words
  after an instruction would be called. This wraps anywhere
  you might see `μ'_i` in the Yellow Paper.
  """

  @spec active_words_after(EVM.Instruction.instruction, EVM.state, EVM.MachineState.t, EVM.ExecEnv.t) :: integer()
  def active_words_after(instruction, state, machine_state, exec_env), do: machine_state.active_words
end