defmodule EVM.Operation.Metadata.BlockInformation do
  @operations for operation <- [
    %{
      id: 0x40,
      description: "Get the hash of one of the 256 most recent complete blocks",
      sym: :blockhash,
      input_count: 1,
      output_count: 1,
      group: :block_information,
    },
    %{
      id: 0x41,
      description: "Get the block’s beneficiary address",
      sym: :coinbase,
      input_count: 0,
      output_count: 1,
      group: :block_information,
    },
    %{
      id: 0x42,
      description: "Get the block’s timestamp",
      sym: :timestamp,
      input_count: 0,
      output_count: 1,
      group: :block_information,
    },
    %{
      id: 0x43,
      description: "Get the block’s number.",
      sym: :number,
      input_count: 0,
      output_count: 1,
      group: :block_information,
    },
    %{
      id: 0x44,
      description: "Get the block’s difficulty.",
      sym: :difficulty,
      input_count: 0,
      output_count: 1,
      group: :block_information,
    },
    %{
      id: 0x45,
      description: "Get the block’s gas limit.",
      sym: :gaslimit,
      input_count: 0,
      output_count: 1,
      group: :block_information,
    },
  ], do: struct(EVM.Operation.Metadata, operation)

  def operations, do: @operations
end
