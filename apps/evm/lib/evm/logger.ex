defmodule EVM.Logger do
  require Logger
  alias EVM.{Operation, MachineState}

  @doc """
  This function logs state in the same format as Parity's `evm-debug` function. This makes comparing implementations and debugging easier.

  `cargo test --features "json-tests evm/evm-debug-tests" --release -- BlockchainTests_GeneralStateTest_stSystemOperationsTest --nocapture`
  """

  @spec log_state_in_parity_format(EVM.Operation.Metadata.t(), MachineState.t()) :: nil
  def log_state_in_parity_format(operation, machine_state) do
    operation_string =
      Atom.to_string(operation.sym)
      |> String.upcase()
      |> String.pad_leading(8)

    opcode_string =
      operation.id
      |> :binary.encode_unsigned()
      |> Base.encode16(case: :lower)
      |> String.trim_leading("0")
      |> String.pad_trailing(2)

    program_counter = machine_state.program_counter + 1

    program_counter_string =
      program_counter
      |> :binary.encode_unsigned()
      |> Base.encode16(case: :lower)
      |> String.trim_leading("0")
      |> String.pad_trailing(3)

    Logger.debug(
      "[0x#{program_counter_string}][#{operation_string}(0x#{opcode_string}) Gas Left: #{
        machine_state.gas
      })"
    )

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
end
