defmodule EVM.MachineState do
  @moduledoc """
  Module for tracking the current machine state, which is roughly
  equivilant to the VM state for an executing contract.

  This is most often seen as µ in the Yellow Paper.
  """

  alias EVM.Gas
  alias EVM.Stack
  alias EVM.MachineState
  alias EVM.ProgramCounter
  alias EVM.ExecEnv
  alias EVM.Operation.Metadata

  # g
  defstruct gas: nil,
            # pc
            program_counter: 0,
            # m
            memory: <<>>,
            # i
            active_words: 0,
            previously_active_words: 0,
            # s
            stack: []

  @type program_counter :: integer()
  @type memory :: binary()
  @type t :: %__MODULE__{
          gas: Gas.t(),
          program_counter: program_counter,
          memory: memory,
          active_words: integer(),
          stack: Stack.t()
        }

  @doc """
  Returns a new execution environment less the amount
  of gas specified.

  ## Examples

      iex> machine_state = %EVM.MachineState{gas: 10, stack: [1, 1], program_counter: 0}
      iex> exec_env = %EVM.ExecEnv{machine_code: <<EVM.Operation.metadata(:add).id>>}
      iex> EVM.MachineState.subtract_gas(machine_state, exec_env)
      %EVM.MachineState{gas: 7, stack: [1, 1]}
  """
  @spec subtract_gas(MachineState.t(), ExecEnv.t()) :: MachineState.t()
  def subtract_gas(machine_state, exec_env) do
    cost = Gas.cost(machine_state, exec_env)

    %{machine_state | gas: machine_state.gas - cost}
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

      iex> %EVM.MachineState{active_words: 2} |> EVM.MachineState.maybe_set_active_words(1)
      %EVM.MachineState{active_words: 2}
  """
  @spec maybe_set_active_words(t, EVM.val()) :: t
  def maybe_set_active_words(machine_state, last_word) do
    %{machine_state | active_words: max(machine_state.active_words, last_word)}
  end

  @doc """
  Pops n values off the stack

  ## Examples

      iex> EVM.MachineState.pop_n(%EVM.MachineState{stack: [1, 2, 3]}, 2)
      {[1 ,2], %EVM.MachineState{stack: [3]}}
  """
  @spec pop_n(MachineState.t(), integer()) :: {list(EVM.val()), MachineState.t()}
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
  @spec push(MachineState.t(), EVM.val()) :: MachineState.t()
  def push(machine_state, value) do
    %{machine_state | stack: Stack.push(machine_state.stack, value)}
  end

  @doc """
  Increments the program counter

  ## Examples

      iex> EVM.MachineState.move_program_counter(%EVM.MachineState{program_counter: 9}, EVM.Operation.metadata(:add), [1, 1])
      %EVM.MachineState{program_counter: 10}
  """
  @spec move_program_counter(MachineState.t(), Metadata.t(), list(EVM.val())) :: MachineState.t()
  def move_program_counter(machine_state, operation_metadata, inputs) do
    next_postion = ProgramCounter.next(machine_state.program_counter, operation_metadata, inputs)

    %{machine_state | program_counter: next_postion}
  end
end
