defmodule EVM.MachineState do
  @moduledoc """
  Module for tracking the current machine state, which is roughly
  equivilant to the VM state for an executing contract.

  This is most often seen as µ in the Yellow Paper.
  """

  alias EVM.ExecEnv
  alias EVM.Gas
  alias EVM.MachineCode
  alias EVM.Stack
  alias EVM.Instruction

  defstruct [
    gas: nil,        # g
    pc: 0,           # pc
    memory: <<>>,    # m
    active_words: 0, # i
    stack: []        # s
  ]

  @type pc :: integer()
  @type memory :: binary()
  @type t :: %{
    gas: Gas.t,
    pc: pc,
    memory: memory,
    active_words: integer(),
    stack: Stack.t,
  }

  @doc """
  Returns the next instruction to execute based on the current
  instruction. This may include a condition check (based on stack)
  to determine branching jump instruction.

  ## Examples

      iex> EVM.MachineState.next_pc(%EVM.MachineState{pc: 4, stack: [100]}, %EVM.ExecEnv{machine_code: EVM.MachineCode.compile([:push1, 3, :push1, 5, :add, :return])}) |> EVM.MachineState.get_pc() # standard add instruction
      5

      iex> EVM.MachineState.next_pc(%EVM.MachineState{pc: 0, stack: [100]}, %EVM.ExecEnv{machine_code: EVM.MachineCode.compile([:push1, 3, :push1, 5, :add, :return])}) |> EVM.MachineState.get_pc() # standard push1 instruction
      2

      iex> EVM.MachineState.next_pc(%EVM.MachineState{pc: 2, stack: [100]}, %EVM.ExecEnv{machine_code: EVM.MachineCode.compile([:push1, 3, :jump, :jumpdest, :return])}) |> EVM.MachineState.get_pc() # direct jump instruction
      100

      iex> EVM.MachineState.next_pc(%EVM.MachineState{pc: 1, stack: [100, 0]}, %EVM.ExecEnv{machine_code: EVM.MachineCode.compile([:push1, 3, :jumpi, :return])}) |> EVM.MachineState.get_pc() # branching jump instruction (fall-through)
      2

      iex> EVM.MachineState.next_pc(%EVM.MachineState{pc: 2, stack: [100, 1]}, %EVM.ExecEnv{machine_code: EVM.MachineCode.compile([:push1, 3, :jumpi, :return])}) |> EVM.MachineState.get_pc() # branching jump instruction (follow)
      100

      iex> EVM.MachineState.next_pc(%EVM.MachineState{pc: 0, stack: []}, %EVM.ExecEnv{machine_code: <<EVM.Instruction.encode(:jumpi)>>}) # branching jump instruction with no stack
      ** (FunctionClauseError) no function clause matching in EVM.Stack.pop_n/2
  """
  @spec next_pc(MachineState.t, ExecEnv.t) :: MachineState.t
  def next_pc(machine_state, exec_env) do
    pc = case MachineCode.current_instruction(machine_state, exec_env) |> Instruction.decode do
      :jump -> jump_location(machine_state)
      :jumpi -> jump_i_location(machine_state)
      w -> Instruction.next_instr_pos(machine_state.pc, w)
    end

    set_pc(machine_state, pc)
  end

  # Location of pc after unconditional jump
  defp jump_location(machine_state) do
    Stack.peek(machine_state.stack)
  end

  # Location of pc after branching jump (jump if not zero)
  defp jump_i_location(machine_state) do
    [jump_location, conditional] = Stack.peek_n(machine_state.stack, 2)

    if conditional != 0 do
      jump_location
    else
      machine_state.pc + 1
    end
  end

  @doc """
  Sets the program counter for a given machine state.

  ## Examples

      iex> EVM.MachineState.set_pc(%EVM.MachineState{pc: 5}, 10)
      %EVM.MachineState{pc: 10}
  """
  @spec set_pc(MachineState.t, pc) :: MachineState.t
  def set_pc(machine_state, pc) do
    %{machine_state | pc: pc}
  end

  @doc """
  Gets the program counter from a given machine state.

  ## Examples

      iex> EVM.MachineState.get_pc(%EVM.MachineState{pc: 5})
      5
  """
  @spec get_pc(MachineState.t) :: pc
  def get_pc(machine_state) do
    machine_state.pc
  end

  @doc """
  Returns a new execution environment less the amount
  of gas specified.

  ## Examples

      iex> %EVM.MachineState{gas: 5} |> EVM.MachineState.subtract_gas(4)
      %EVM.MachineState{gas: 1}

      iex> %EVM.MachineState{gas: 5} |> EVM.MachineState.subtract_gas(6)
      ** (MatchError) no match of right hand side value: false
  """
  @spec subtract_gas(t, EVM.Gas.t) :: t
  def subtract_gas(exec_env, gas) do
    true = (exec_env.gas >= gas) # assertion

    %{exec_env| gas: exec_env.gas - gas}
  end

  @doc """
  After a memory operation, we may have incremented the total number
  of active words. This function takes a memory offset accessed and
  updates the machine state accordingly.

  ## Examples

      iex> %EVM.MachineState{active_words: 2} |> EVM.MachineState.maybe_set_active_words(1)
      %EVM.MachineState{active_words: 2}

      iex> %EVM.MachineState{active_words: 2} |> EVM.MachineState.maybe_set_active_words(3)
      %EVM.MachineState{active_words: 3}
  """
  @spec maybe_set_active_words(t, EVM.val) :: t
  def maybe_set_active_words(machine_state, last_word) do
    %{machine_state | active_words: max(machine_state.active_words, last_word)}
  end

end