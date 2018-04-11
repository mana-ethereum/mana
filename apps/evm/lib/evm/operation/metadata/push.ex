defmodule EVM.Operation.Metadata.Push do
  @operations for n <- 1..32,
                  do: %EVM.Operation.Metadata{
                    # 0x60..0x7f
                    id: n + 0x5F,
                    sym: :"push#{n}",
                    description: "Place #{n}-byte item on stack",
                    fun: :push_n,
                    args: [n],
                    input_count: 0,
                    output_count: n,
                    group: :push,
                    machine_code_offset: n
                  }
  def operations, do: @operations
end
