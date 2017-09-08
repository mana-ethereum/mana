defmodule EVM.Operation.Metadata.Duplication do
  @operations for n <- 1..17, do:
    %EVM.Operation.Metadata{
      id: n + 0x7f, # 0x80..0x8e
      sym: :"dup#{n}",
      description: "Duplicate #{n}st stack item.",
      fun: :dup,
      input_count: n,
      output_count: 2,
      group: :duplication,
    }
  def operations, do: @operations
end
