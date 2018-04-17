defmodule EVM.Operation.Metadata.SHA3 do
  @operations [
    %EVM.Operation.Metadata{
      id: 0x20,
      description: "Compute Keccak-256 hash.",
      sym: :sha3,
      input_count: 2,
      output_count: 1,
      group: :sha3
    }
  ]

  def operations, do: @operations
end
