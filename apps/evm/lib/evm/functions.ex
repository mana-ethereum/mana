defmodule EVM.Functions do
  @moduledoc """
  Set of functions defined in the Yellow Paper that do not logically
  fit in other modules.
  """

  alias EVM.{Configuration, ExecEnv, Gas, MachineCode, MachineState, Operation, Stack}
  alias EVM.Operation.Metadata

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
    operation_metadata = operation_metadata(operation, exec_env)
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

      not_enough_gas?(machine_state, exec_env) ->
        {:halt, :out_of_gas}

      Stack.length(machine_state.stack) - input_count + output_count > @max_stack ->
        {:halt, :stack_overflow}

      is_invalid_jump_destination?(operation_metadata, inputs, exec_env.machine_code) ->
        {:halt, :invalid_jump_destination}

      exec_env.static && static_state_modification?(operation_metadata.sym, inputs) ->
        {:halt, :static_state_modification}

      out_of_memory_bounds?(operation_metadata.sym, machine_state, inputs) ->
        {:halt, :out_of_memory_bounds}

      true ->
        :continue
    end
  end

  # credo:disable-for-next-line
  def operation_metadata(operation, exec_env) do
    operation_metadata = Operation.metadata(operation)

    if operation_metadata do
      config = exec_env.config

      case operation_metadata.sym do
        :delegatecall ->
          if Configuration.for(config).has_delegate_call?(config), do: operation_metadata

        :revert ->
          if Configuration.for(config).has_revert?(config), do: operation_metadata

        :staticcall ->
          if Configuration.for(config).has_static_call?(config), do: operation_metadata

        :returndatasize ->
          if Configuration.for(config).support_variable_length_return_value?(config),
            do: operation_metadata

        :returndatacopy ->
          if Configuration.for(config).support_variable_length_return_value?(config),
            do: operation_metadata

        :shl ->
          if Configuration.for(config).has_shift_operations?(config), do: operation_metadata

        :shr ->
          if Configuration.for(config).has_shift_operations?(config), do: operation_metadata

        :sar ->
          if Configuration.for(config).has_shift_operations?(config), do: operation_metadata

        :extcodehash ->
          if Configuration.for(config).has_extcodehash?(config), do: operation_metadata

        :create2 ->
          if Configuration.for(config).has_create2?(config), do: operation_metadata

        _ ->
          operation_metadata
      end
    end
  end

  @spec not_enough_gas?(MachineState.t(), ExecEnv.t()) :: boolean()
  defp not_enough_gas?(machine_state, exec_env) do
    cost = Gas.cost(machine_state, exec_env)

    cost > machine_state.gas
  end

  @spec out_of_memory_bounds?(atom(), MachineState.t(), [EVM.val()]) :: boolean()
  defp out_of_memory_bounds?(:returndatacopy, machine_state, [
         _memory_start,
         return_data_start,
         size
       ]) do
    return_data_start + size > byte_size(machine_state.last_return_data)
  end

  defp out_of_memory_bounds?(_, _, _), do: false

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

  defp static_state_modification?(:call, [_, _, value, _, _, _, _]), do: value > 0

  defp static_state_modification?(:log0, _), do: true

  defp static_state_modification?(:log1, _), do: true

  defp static_state_modification?(:log2, _), do: true

  defp static_state_modification?(:log3, _), do: true

  defp static_state_modification?(:log4, _), do: true

  defp static_state_modification?(:selfdestruct, _), do: true

  defp static_state_modification?(:create, _), do: true

  defp static_state_modification?(:create2, _), do: true

  defp static_state_modification?(:sstore, _), do: true

  defp static_state_modification?(_, _), do: false
end
