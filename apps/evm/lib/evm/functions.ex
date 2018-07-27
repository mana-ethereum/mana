defmodule EVM.Functions do
  @moduledoc """
  Set of functions defined in the Yellow Paper that do not logically
  fit in other modules.
  """

  alias EVM.{ExecEnv, MachineCode, MachineState, Operation, Stack, Gas}
  alias EVM.Operation.Metadata

  @max_stack 1024
  @max_int (2 |> :math.pow(256) |> round) - 1

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

      iex> EVM.Functions.is_normal_halting?(%EVM.MachineState{program_counter: 0}, %EVM.ExecEnv{machine_code: <<EVM.Operation.encode(:selfdestruct)>>})
      <<>>

      iex> EVM.Functions.is_normal_halting?(%EVM.MachineState{stack: [0, 1], memory: <<0xabcd::16>>}, %EVM.ExecEnv{machine_code: <<EVM.Operation.encode(:return)>>})
      <<0xab>>

      iex> EVM.Functions.is_normal_halting?(%EVM.MachineState{stack: [0, 2], memory: <<0xabcd::16>>}, %EVM.ExecEnv{machine_code: <<EVM.Operation.encode(:return)>>})
      <<0xab, 0xcd>>

      iex> EVM.Functions.is_normal_halting?(%EVM.MachineState{stack: [1, 1], memory: <<0xabcd::16>>}, %EVM.ExecEnv{machine_code: <<EVM.Operation.encode(:return)>>})
      <<0xcd>>
  """
  @spec is_normal_halting?(MachineState.t(), ExecEnv.t()) :: nil | binary() | {atom(), binary()}
  def is_normal_halting?(machine_state, exec_env) do
    case MachineCode.current_operation(machine_state, exec_env).sym do
      :return -> h_return(machine_state)
      :revert -> {:revert, h_return(machine_state)}
      x when x == :stop or x == :selfdestruct -> <<>>
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

  This is defined as `Z` in Eq.(137) of the Yellow Paper.

  ## Examples

      # TODO: Once we add gas cost, make this more reasonable
      # TODO: How do we pass in state?
      iex> EVM.Functions.is_exception_halt?(%EVM.MachineState{program_counter: 0, gas: 0xffff}, %EVM.ExecEnv{machine_code: <<0xfee>>})
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

      iex> EVM.Functions.is_exception_halt?(%EVM.MachineState{program_counter: 0, gas: 0xffff, stack: []}, %EVM.ExecEnv{machine_code: <<EVM.Operation.encode(:invalid)>>})
      {:halt, :invalid_instruction}
  """
  @spec is_exception_halt?(MachineState.t(), ExecEnv.t()) :: :continue | {:halt, atom()}
  # credo:disable-for-next-line
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
      is_invalid_instruction?(operation_metadata) ->
        {:halt, :invalid_instruction}

      is_nil(input_count) ->
        {:halt, :undefined_instruction}

      length(machine_state.stack) < input_count ->
        {:halt, :stack_underflow}

      not_enough_gas?(machine_state, exec_env, operation_metadata, inputs) ->
        {:halt, :out_of_gas}

      Stack.length(machine_state.stack) - input_count + output_count > @max_stack ->
        {:halt, :stack_overflow}

      is_invalid_jump_destination?(operation_metadata, inputs, exec_env.machine_code) ->
        {:halt, :invalid_jump_destination}

      true ->
        :continue
    end
  end

  @spec not_enough_gas?(MachineState.t(), ExecEnv.t(), Metadata.t(), [EVM.val()]) :: boolean()
  defp not_enough_gas?(machine_state, exec_env, metadata, inputs) do
    cost = Gas.cost(machine_state, exec_env)

    cost > machine_state.gas || nested_operation_gas_overflow?(metadata.sym, cost, inputs)
  end

  @spec nested_operation_gas_overflow?(atom(), integer(), [EVM.val()]) :: boolean()
  defp nested_operation_gas_overflow?(:call, cost, [call_gas, _, _, _, _, _, _]) do
    call_gas + cost > @max_int
  end

  defp nested_operation_gas_overflow?(:callcode, cost, [call_gas, _, _, _, _, _, _]) do
    call_gas + cost > @max_int
  end

  defp nested_operation_gas_overflow?(_, _, _) do
    false
  end

  @spec is_invalid_instruction?(Metadata.t()) :: boolean()
  defp is_invalid_instruction?(%Metadata{sym: :invalid}), do: true

  defp is_invalid_instruction?(_), do: false

  @spec is_invalid_jump_destination?(Metadata.t(), [EVM.val()], MachineCode.t()) :: boolean()
  defp is_invalid_jump_destination?(%Metadata{sym: :jump}, [position], machine_code) do
    not MachineCode.valid_jump_dest?(position, machine_code)
  end

  defp is_invalid_jump_destination?(%Metadata{sym: :jumpi}, [position, condition], machine_code) do
    condition != 0 && not MachineCode.valid_jump_dest?(position, machine_code)
  end

  defp is_invalid_jump_destination?(_operation, _inputs, _machine_code), do: false
end
