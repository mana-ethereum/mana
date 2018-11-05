defmodule EVM.Logger do
  require Logger
  alias EVM.{MachineState, Operation}

  @doc """
  Helper function to log the stack given the machine state
  """
  @spec log_stack(MachineState.t()) :: MachineState.t()
  def log_stack(machine_state) do
    stack =
      machine_state.stack
      |> Enum.map(&stack_value_string/1)

    _ = Logger.debug(fn -> "Stack: #{inspect(stack)}" end)
    machine_state
  end

  @doc """
  This function logs state in the same format as Parity's `evm-debug` function. This makes comparing implementations and debugging easier.

  `cargo test --features "json-tests evm/evm-debug-tests" --release -- BlockchainTests_GeneralStateTest_stSystemOperationsTest --nocapture`
  """
  @spec log_state(MachineState.t(), EVM.Operation.Metadata.t()) :: MachineState.t()
  def log_state(machine_state, operation) do
    _ = log_opcode_and_gas_left(operation, machine_state)
    _ = log_inputs(operation, machine_state)
    machine_state
  end

  defp log_opcode_and_gas_left(operation, machine_state) do
    Logger.debug(fn ->
      "[#{current_step(machine_state)}] pc(#{machine_state.program_counter}) [#{
        operation_string(operation)
      }(0x#{opcode_string(operation)}) Gas Left: #{machine_state.gas})"
    end)
  end

  defp log_inputs(operation, machine_state) do
    inputs = Operation.inputs(operation, machine_state)

    if !Enum.empty?(inputs) do
      inputs
      |> Enum.reverse()
      |> Stream.with_index()
      |> Enum.each(fn {value, i} ->
        value_string = stack_value_string(value)
        Logger.debug(fn -> "       | #{i}: #{value_string}" end)
      end)
    end
  end

  defp current_step(machine_state) do
    machine_state.step + 1
  end

  defp stack_value_string(0), do: "0x0"

  defp stack_value_string(value) do
    string_value =
      value
      |> :binary.encode_unsigned()
      |> Base.encode16(case: :lower)
      |> String.trim_leading("0")

    "0x" <> string_value
  end

  defp operation_string(operation) do
    operation.sym
    |> Atom.to_string()
    |> String.upcase()
    |> String.pad_leading(8)
  end

  defp opcode_string(operation) do
    operation.id
    |> :binary.encode_unsigned()
    |> Base.encode16(case: :lower)
    |> String.trim_leading("0")
    |> String.pad_trailing(2)
  end
end
