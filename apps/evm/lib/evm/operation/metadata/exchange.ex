defmodule EVM.Operation.Metadata.Exchange do
  @operations for n <- 1..17, do:
    %EVM.Operation.Metadata{
      id: n + 0x8f, # 0x90..0x9e
      description: "Exchange #{n}st and #{n+1}nd stack items.",
      sym: :"swap#{n}",
      fun: :swap,
      input_count: n + 1,
      output_count: 2,
      group: :exchange,
    }

  def operations, do: @operations
end
