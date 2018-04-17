defmodule EVM.Functions do
  @moduledoc """
  Set of functions defined in the Yellow Paper that do not logically
  fit in other modules.
  """

  alias EVM.ExecEnv
  alias EVM.MachineCode
  alias EVM.MachineState
  alias EVM.Operation
  alias EVM.Stack
  alias EVM.Gas

  @max_stack 1024

  def max_stack_depth, do: @max_stack

  @doc """
  Returns whether or not the current program is halting due to a `return` or terminal statement.

  # Examples

      iex> EVM.Functions.is_normal_halting?(%EVM.MachineState{program_counter: 0}, %EVM.ExecEnv{machine_code: <<EVM.Operation.encode(:add)>>})
      nil

      iex> EVM.Functions.is_normal_halting?(%EVM.MachineState{program_counter: 0}, %EVM.ExecEnv{machine_code: <<EVM.Operation.encode(:mul)>>})
      nil

      iex> EVM.Functions.is_normal_halting?(%EVM.MachineState{program_counter: 0}, %EVM.ExecEnv{machine_code: <<EVM.Operation.encode(:stop)>>})
      <<>>

      iex> EVM.Functions.is_normal_halting?(%EVM.MachineState{program_counter: 0}, %EVM.ExecEnv{machine_code: <<EVM.Operation.encode(:suicide)>>})
      <<>>

      iex> EVM.Functions.is_normal_halting?(%EVM.MachineState{stack: [0, 1], memory: <<0xabcd::16>>}, %EVM.ExecEnv{machine_code: <<EVM.Operation.encode(:return)>>})
      <<0xab>>

      iex> EVM.Functions.is_normal_halting?(%EVM.MachineState{stack: [0, 2], memory: <<0xabcd::16>>}, %EVM.ExecEnv{machine_code: <<EVM.Operation.encode(:return)>>})
      <<0xab, 0xcd>>

      iex> EVM.Functions.is_normal_halting?(%EVM.MachineState{stack: [1, 1], memory: <<0xabcd::16>>}, %EVM.ExecEnv{machine_code: <<EVM.Operation.encode(:return)>>})
      <<0xcd>>
  """
  @spec is_normal_halting?(MachineState.t(), ExecEnv.t()) :: nil | binary()
  def is_normal_halting?(machine_state, exec_env) do
    case MachineCode.current_operation(machine_state, exec_env).sym do
      :return -> h_return(machine_state)
      x when x == :stop or x == :suicide -> <<>>
      _ -> nil
    end
  end

  # Defined in Appendix H of the Yellow Paper
  @spec h_return(MachineState.t()) :: binary()
  defp h_return(machine_state) do
    {[offset, length], _} = EVM.Stack.pop_n(machine_state.stack, 2)

    {result, _} = EVM.Memory.read(machine_state, offset, length)

    result
  end

  @doc """
  Returns whether or not the current program is in an exceptional halting state.
  This may be due to running out of gas, having an invalid instruction, having
  a stack underflow, having an invalid jump destination or having a stack overflow.

  This is defined as `Z` in Eq.(126) of the Yellow Paper.

  ## Examples

      # TODO: Once we add gas cost, make this more reasonable
      # TODO: How do we pass in state?
      iex> EVM.Functions.is_exception_halt?(%EVM.MachineState{program_counter: 0, gas: 0xffff}, %EVM.ExecEnv{machine_code: <<0xfe>>})
      {:halt, :undefined_instruction}

      iex> EVM.Functions.is_exception_halt?(%EVM.MachineState{program_counter: 0, gas: 0xffff, stack: []}, %EVM.ExecEnv{machine_code: <<EVM.Operation.encode(:add)>>})
      {:halt, :stack_underflow}

      iex> EVM.Functions.is_exception_halt?(%EVM.MachineState{program_counter: 0, gas: 0xffff, stack: [5]}, %EVM.ExecEnv{machine_code: <<EVM.Operation.encode(:jump)>>})
      {:halt, :invalid_jump_destination}

      iex> EVM.Functions.is_exception_halt?(%EVM.MachineState{program_counter: 0, gas: 0xffff, stack: [1]}, %EVM.ExecEnv{machine_code: <<EVM.Operation.encode(:jump), EVM.Operation.encode(:jumpdest)>>})
      :continue

      iex> EVM.Functions.is_exception_halt?(%EVM.MachineState{program_counter: 0, gas: 0xffff, stack: [1, 5]}, %EVM.ExecEnv{machine_code: <<EVM.Operation.encode(:jumpi)>>})
      {:halt, :invalid_jump_destination}

      iex> EVM.Functions.is_exception_halt?(%EVM.MachineState{program_counter: 0, gas: 0xffff, stack: [1, 5]}, %EVM.ExecEnv{machine_code: <<EVM.Operation.encode(:jumpi), EVM.Operation.encode(:jumpdest)>>})
      :continue

      iex> EVM.Functions.is_exception_halt?(%EVM.MachineState{program_counter: 0, gas: 0xffff, stack: (for _ <- 1..1024, do: 0x0)}, %EVM.ExecEnv{machine_code: <<EVM.Operation.encode(:stop)>>})
      :continue

      iex> EVM.Functions.is_exception_halt?(%EVM.MachineState{program_counter: 0, gas: 0xffff, stack: (for _ <- 1..1024, do: 0x0)}, %EVM.ExecEnv{machine_code: <<EVM.Operation.encode(:push1)>>})
      {:halt, :stack_overflow}
  """
  @spec is_exception_halt?(MachineState.t, ExecEnv.t) :: :continue | {:halt, atom()}
  def is_exception_halt?(machine_state, exec_env) do
    operation = Operation.get_operation_at(exec_env.machine_code, machine_state.program_counter)
    operation_metadata = Operation.metadata(operation)
    # dw
    input_count = Map.get(operation_metadata || %{}, :input_count)
    # aw
    output_count = Map.get(operation_metadata || %{}, :output_count)

    inputs =
      if operation_metadata do
        Operation.inputs(operation_metadata, machine_state)
      end

    cond do
      is_nil(operation) || is_nil(input_count) ->
        {:halt, :undefined_instruction}

      length(machine_state.stack) < input_count ->
        {:halt, :stack_underflow}

      Gas.cost(machine_state, exec_env) > machine_state.gas ->
        {:halt, :out_of_gas}

      Stack.length(machine_state.stack) - input_count + output_count > @max_stack ->
        {:halt, :stack_overflow}

      is_invalid_jump_destination?(operation_metadata, inputs, exec_env.machine_code) ->
        {:halt, :invalid_jump_destination}

      true ->
        :continue
    end
  end

  defp is_invalid_jump_destination?(%{sym: :jump}, [position], machine_code) do
    not MachineCode.valid_jump_dest?(position, machine_code)
  end

  defp is_invalid_jump_destination?(%{sym: :jumpi}, [position, condition], machine_code) do
    condition != 0 && not MachineCode.valid_jump_dest?(position, machine_code)
  end

  defp is_invalid_jump_destination?(_operation, _inputs, _machine_code), do: false
end
