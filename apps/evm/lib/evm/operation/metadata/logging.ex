defmodule EVM.Operation.Metadata.Logging do
  @operations for n <- 0..4,
                  do: %EVM.Operation.Metadata{
                    # 0xa0 - 0xa3
                    id: 0xA0 + n,
                    description: "Append log record with no topics.",
                    sym: :"log#{n}",
                    input_count: 2 + n,
                    output_count: 0,
                    group: :logging
                  }

  def operations, do: @operations
end
