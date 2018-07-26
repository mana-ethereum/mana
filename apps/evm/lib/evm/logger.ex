defmodule EVM.Logger do
  require Logger
  alias EVM.{Operation, MachineState}

  @doc """
  This function logs state in the same format as Parity's `evm-debug` function. This makes comparing implementations and debugging easier.

  `cargo test --features "json-tests evm/evm-debug-tests" --release -- BlockchainTests_GeneralStateTest_stSystemOperationsTest --nocapture`
  """

  @spec log_state(EVM.Operation.Metadata.t(), MachineState.t()) :: nil
  def log_state(operation, machine_state) do
    log_opcode_and_gas_left(operation, machine_state)
    log_inputs(operation, machine_state)
  end

  defp log_opcode_and_gas_left(operation, machine_state) do
    Logger.debug(
      "[0x#{program_counter_string(machine_state)}][#{operation_string(operation)}(0x#{
        opcode_string(operation)
      }) Gas Left: #{machine_state.gas})"
    )
  end

  defp log_inputs(operation, machine_state) do
    inputs = Operation.inputs(operation, machine_state)

    if !Enum.empty?(inputs) do
      inputs
      |> Enum.reverse()
      |> Stream.with_index()
      |> Enum.each(fn {value, i} ->
        value_string =
          if value == 0,
            do: "0",
            else:
              value
              |> :binary.encode_unsigned()
              |> Base.encode16(case: :lower)
              |> String.trim_leading("0")

        Logger.debug("       | #{i}: 0x#{value_string}")
      end)
    end
  end

  defp operation_string(operation),
    do:
      Atom.to_string(operation.sym)
      |> String.upcase()
      |> String.pad_leading(8)

  defp opcode_string(operation),
    do:
      operation.id
      |> :binary.encode_unsigned()
      |> Base.encode16(case: :lower)
      |> String.trim_leading("0")
      |> String.pad_trailing(2)

  defp program_counter_string(machine_state) do
    program_counter = machine_state.program_counter + 1

    program_counter
    |> :binary.encode_unsigned()
    |> Base.encode16(case: :lower)
    |> String.trim_leading("0")
    |> String.pad_trailing(3)
  end
end
