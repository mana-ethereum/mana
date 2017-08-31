defmodule EVM.Operation.Metadata.Logging do
  @operations for n <- 0..4, do:
    %EVM.Operation.Metadata{
      id: 0xa0 + n, # 0xa0 - 0xa3
      description: "Append log record with no topics.",
      sym: :"log#{n}",
      input_count: 2,
      output_count: 0,
      group: :logging,
    }

  def operations, do: @operations
end
