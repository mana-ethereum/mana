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
  alias EVM.Operation
  alias EVM.MachineState

  defstruct [
    gas: nil,          # g
    pc: 0,             # pc
    memory: <<>>,      # m
    active_words: 0,   # i
    previously_active_words: 0,
    stack: []          # s
  ]

  @type pc :: integer()
  @type memory :: binary()
  @type t :: %__MODULE__{
    gas: Gas.t,
    pc: pc,
    memory: memory,
    active_words: integer(),
    stack: Stack.t,
  }

  @doc """
  Returns a new execution environment less the amount
  of gas specified.

  ## Examples

      iex> %EVM.MachineState{gas: 5} |> EVM.MachineState.subtract_gas(4)
      %EVM.MachineState{gas: 1}
  """
  @spec subtract_gas(t, EVM.Gas.t) :: t
  def subtract_gas(machine_state, gas) do
    %{machine_state| gas: machine_state.gas - gas}
  end

  @doc """
  After a memory operation, we may have incremented the total number
  of active words. This function takes a memory offset accessed and
  updates the machine state accordingly.

  ## Examples

      iex> %EVM.MachineState{active_words: 2, previously_active_words: 1} |> EVM.MachineState.maybe_set_active_words(1)
      %EVM.MachineState{active_words: 2, previously_active_words: 2}

      iex> %EVM.MachineState{active_words: 2, previously_active_words: 1} |> EVM.MachineState.maybe_set_active_words(3)
      %EVM.MachineState{active_words: 3, previously_active_words: 2}

      iex> %EVM.MachineState{active_words: 2, previously_active_words: 1} |> EVM.MachineState.maybe_set_active_words(1)
      %EVM.MachineState{active_words: 2, previously_active_words: 2}
  """
  @spec maybe_set_active_words(t, EVM.val) :: t
  def maybe_set_active_words(machine_state, last_word) do
    machine_state = %{machine_state | previously_active_words: machine_state.active_words}

    %{machine_state | active_words: max(machine_state.active_words, last_word)}
  end

  @doc """
  Pops n values off the stack

  ## Examples

      iex> EVM.MachineState.pop_n(%EVM.MachineState{stack: [1, 2, 3]}, 2)
      {[1 ,2], %EVM.MachineState{stack: [3]}}
  """
  @spec pop_n(MachineState.t, pc) :: {MachineState.t, list(EVM.val)}
  def pop_n(machine_state, n) do
    {values, stack} = Stack.pop_n(machine_state.stack, n)
    machine_state = %{machine_state | stack: stack}
    {values, machine_state}
  end

  @doc """
  Push a values onto the stack

  ## Examples

      iex> EVM.MachineState.push(%EVM.MachineState{stack: [2, 3]}, 1)
      %EVM.MachineState{stack: [1, 2, 3]}
  """
  @spec push(MachineState.t, EVM.val) :: MachineState.t
  def push(machine_state, value) do
    %{machine_state | stack: Stack.push(machine_state.stack, value)}
  end

  @doc """
  Increments the program counter

  ## Examples

      iex> EVM.MachineState.next_pc(%EVM.MachineState{pc: 9}, :add)
      %EVM.MachineState{pc: 10}
  """
  @spec next_pc(MachineState.t, atom()) :: MachineState.t
  def next_pc(machine_state, operation) do
    if operation in Operation.jump_operations() do
      machine_state
    else
      %{machine_state | pc: machine_state.pc + 1}
    end
  end

end
