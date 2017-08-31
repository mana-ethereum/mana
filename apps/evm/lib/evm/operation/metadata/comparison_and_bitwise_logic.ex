defmodule EVM.Operation.Metadata.ComparisonAndBitwiseLogic do
  @operations for operation <- [
    %{
      id: 0x10,
      description: "Less-than comparision.",
      sym: :lt,
      input_count: 2,
      output_count: 1,
      group: :comparison_and_bitwise_logic
    },
    %{
      id: 0x11,
      description: "Greater-than comparision.",
      sym: :gt,
      input_count: 2,
      output_count: 1,
      group: :comparison_and_bitwise_logic
    },
    %{
      id: 0x12,
      description: "Signed less-than comparision.",
      sym: :slt,
      input_count: 2,
      output_count: 1,
      group: :comparison_and_bitwise_logic
    },
    %{
      id: 0x13,
      description: "Signed greater-than comparision",
      sym: :sgt,
      input_count: 2,
      output_count: 1,
      group: :comparison_and_bitwise_logic
    },
    %{
      id: 0x14,
      description: "Equality comparision.",
      sym: :eq,
      input_count: 2,
      output_count: 1,
      group: :comparison_and_bitwise_logic
    },
    %{
      id: 0x15,
      description: "Simple not operator.",
      sym: :iszero,
      input_count: 1,
      output_count: 1,
      group: :comparison_and_bitwise_logic
    },
    %{
      id: 0x16,
      description: "Bitwise AND operation.",
      sym: :and_,
      input_count: 2,
      output_count: 1,
      group: :comparison_and_bitwise_logic
    },
    %{
      id: 0x17,
      description: "Bitwise OR operation.",
      sym: :or_,
      input_count: 2,
      output_count: 1,
      group: :comparison_and_bitwise_logic
    },
    %{
      id: 0x18,
      description: "Bitwise XOR operation.",
      sym: :xor_,
      input_count: 2,
      output_count: 1,
      group: :comparison_and_bitwise_logic
    },
    %{
      id: 0x19,
      description: "Bitwise NOT operation.",
      sym: :not_,
      input_count: 1,
      output_count: 1,
      group: :comparison_and_bitwise_logic
    },
    %{
      id: 0x1a,
      description: "Retrieve single byte from word.",
      sym: :byte,
      input_count: 2,
      output_count: 1,
      group: :comparison_and_bitwise_logic
    },
  ], do: struct(EVM.Operation.Metadata, operation)

  def operations, do: @operations
end
