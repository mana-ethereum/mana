defmodule EVM.Operation.Metadata.StopAndArithmetic do
  @operations for operation <- [
    %{
      id: 0x00,
      description: "Halts execution",
      sym: :stop,
      group: :stop_and_arithmetic,
      input_count: 0,
      output_count: 0
    },
    %{
      id: 0x01,
      description: "Addition operation",
      sym: :add,
      group: :stop_and_arithmetic,
      input_count: 2,
      output_count: 1
    },
    %{
      id: 0x02,
      description: "Multiplication operation.",
      sym: :mul,
      group: :stop_and_arithmetic,
      input_count: 2,
      output_count: 1
    },
    %{
      id: 0x03,
      description: "Subtraction operation.",
      sym: :sub,
      group: :stop_and_arithmetic,
      input_count: 2,
      output_count: 1
    },
    %{
      id: 0x04,
      description: "Integer division operation.",
      sym: :div,
      group: :stop_and_arithmetic,
      input_count: 2,
      output_count: 1
    },
    %{
      id: 0x05,
      description: "Signed integer division operation (truncated).",
      sym: :sdiv,
      group: :stop_and_arithmetic,
      input_count: 2,
      output_count: 1
    },
    %{
      id: 0x06,
      description: "Modulo remainder operation.",
      sym: :mod,
      group: :stop_and_arithmetic,
      input_count: 2,
      output_count: 1
    },
    %{
      id: 0x07,
      description: "Signed modulo remainder operation.",
      sym: :smod,
      group: :stop_and_arithmetic,
      input_count: 2,
      output_count: 1
    },
    %{
      id: 0x08,
      description: "Modulo addition operation.",
      sym: :addmod,
      group: :stop_and_arithmetic,
      input_count: 3,
      output_count: 1
    },
    %{
      id: 0x09,
      description: "Modulo multiplication operation.",
      sym: :mulmod,
      group: :stop_and_arithmetic,
      input_count: 3,
      output_count: 1
    },
    %{
      id: 0x0a,
      description: "Exponential operation",
      sym: :exp,
      group: :stop_and_arithmetic,
      input_count: 2,
      output_count: 1
    },
    %{
      id: 0x0b,
      description: "Extend length of two’s complement signed integer.",
      sym: :signextend,
      group: :stop_and_arithmetic,
      input_count: 2,
      output_count: 1
    }
  ], do: struct(EVM.Operation.Metadata, operation)

  def operations, do: @operations
end
