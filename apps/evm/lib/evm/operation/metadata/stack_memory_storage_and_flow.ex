defmodule EVM.Operation.Metadata.StackMemoryStorageAndFlow do
  @operations for operation <- [
    %{
      id: 0x50,
      description: "Remove item from stack.",
      sym: :pop,
      input_count: 1,
      output_count: 0,
      group: :stack_memory_storage_and_flow
    },
    %{
      id: 0x51,
      description: "Load word from memory",
      sym: :mload,
      input_count: 1,
      output_count: 1,
      group: :stack_memory_storage_and_flow
    },
    %{
      id: 0x52,
      description: "Save word to memory.",
      sym: :mstore,
      input_count: 2,
      output_count: 0,
      group: :stack_memory_storage_and_flow
    },
    %{
      id: 0x53,
      description: "Save byte to memory.",
      sym: :mstore8,
      input_count: 2,
      output_count: 0,
      group: :stack_memory_storage_and_flow
    },
    %{
      id: 0x54,
      description: "Load word from storage",
      sym: :sload,
      input_count: 1,
      output_count: 1,
      group: :stack_memory_storage_and_flow
    },
    %{
      id: 0x55,
      description: "Save word to storage",
      sym: :sstore,
      input_count: 2,
      output_count: 0,
      group: :stack_memory_storage_and_flow
    },
    %{
      id: 0x56,
      description: "Alter the program counter.",
      sym: :jump,
      input_count: 1,
      output_count: 0,
      group: :stack_memory_storage_and_flow
    },
    %{
      id: 0x57,
      description: "Conditionally alter the program counter.",
      sym: :jumpi,
      input_count: 2,
      output_count: 0,
      group: :stack_memory_storage_and_flow
    },
    %{
      id: 0x58,
      description: "Get the value of the program counter prior to the increment corresponding to this operation.",
      sym: :pc,
      input_count: 0,
      output_count: 1,
      group: :stack_memory_storage_and_flow
    },
    %{
      id: 0x59,
      description: "Get the size of active memory in bytes",
      sym: :msize,
      input_count: 0,
      output_count: 1,
      group: :stack_memory_storage_and_flow
    },
    %{
      id: 0x5a,
      description: "Get the amount of available gas, including the corresponding reduction for the cost of this operation.",
      sym: :gas,
      input_count: 0,
      output_count: 1,
      group: :stack_memory_storage_and_flow
    },
    %{
      id: 0x5b,
      description: "Mark a valid destination for jumps.",
      sym: :jumpdest,
      input_count: 0,
      output_count: 0,
      group: :stack_memory_storage_and_flow
    }], do: struct(EVM.Operation.Metadata, operation)

  def operations, do: @operations
end
