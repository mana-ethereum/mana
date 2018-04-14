defmodule EVM.Operation.Metadata.Duplication do
  @operations for n <- 1..17,
                  do: %EVM.Operation.Metadata{
                    # 0x80..0x8e
                    id: n + 0x7F,
                    sym: :"dup#{n}",
                    description: "Duplicate #{n}st stack item.",
                    fun: :dup,
                    input_count: n,
                    output_count: 2,
                    group: :duplication
                  }
  def operations, do: @operations
end
