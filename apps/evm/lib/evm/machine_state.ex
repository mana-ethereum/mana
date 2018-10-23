defmodule EVM.MachineState do
  @moduledoc """
  Module for tracking the current machine state, which is roughly
  equivalent to the VM state for an executing contract.

  This is most often seen as µ in the Yellow Paper.
  """

  alias EVM.{ExecEnv, Gas, MachineState, ProgramCounter, Stack}
  alias EVM.Operation.Metadata

  defstruct gas: nil,
            program_counter: 0,
            memory: <<>>,
            active_words: 0,
            previously_active_words: 0,
            stack: [],
            last_return_data: <<>>,
            step: 0

  @type program_counter :: integer()
  @type memory :: binary()
  @typedoc """
  Yellow paper terms:

  - g: gas
  - pc: program_counter
  - m: memory
  - i: active_words
  - s: stack

  Other terms:

  - step: the number of vm cycles the machine state gas gone through
  """
  @type t :: %__MODULE__{
          gas: Gas.t(),
          program_counter: program_counter,
          memory: memory,
          active_words: integer(),
          previously_active_words: integer(),
          stack: Stack.t(),
          last_return_data: binary(),
          step: integer()
        }

  @doc """
  Subtracts gas required by the current instruction from the specified machine
  state.

  ## Examples

      iex> machine_state = %EVM.MachineState{gas: 10, stack: [1, 1], program_counter: 0}
      iex> exec_env = %EVM.ExecEnv{machine_code: <<EVM.Operation.metadata(:add).id>>}
      iex> EVM.MachineState.subtract_gas(machine_state, exec_env)
      %EVM.MachineState{gas: 7, stack: [1, 1]}
  """
  @spec subtract_gas(MachineState.t(), ExecEnv.t()) :: MachineState.t()
  def subtract_gas(machine_state, exec_env) do
    case Gas.cost_with_status(machine_state, exec_env) do
      {:changed, cost, new_call_gas} ->
        new_stack = Stack.replace(machine_state.stack, 0, new_call_gas)

        %{machine_state | gas: machine_state.gas - cost, stack: new_stack}

      {:original, cost} ->
        %{machine_state | gas: machine_state.gas - cost}
    end
  end

  @doc """
  Refunds gas in the machine state

  ## Examples

      iex> machine_state = %EVM.MachineState{gas: 5}
      iex> EVM.MachineState.refund_gas(machine_state, 5)
      %EVM.MachineState{gas: 10}
  """
  @spec refund_gas(MachineState.t(), integer()) :: MachineState.t()
  def refund_gas(machine_state, amount) do
    %{machine_state | gas: machine_state.gas + amount}
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
  Pops n values off the stack.

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

  @doc """
  Increments the step (representing another vm cycle)

  ## Examples

      iex> EVM.MachineState.increment_step(%EVM.MachineState{step: 9})
      %EVM.MachineState{step: 10}
  """
  @spec increment_step(MachineState.t()) :: MachineState.t()
  def increment_step(machine_state) do
    %{machine_state | step: machine_state.step + 1}
  end
end
