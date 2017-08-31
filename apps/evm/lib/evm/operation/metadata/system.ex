defmodule EVM.Operation.Metadata.System do
  @operations for operation <- [
    %{
      id: 0xf0,
      description: "Create a new account with associated code.",
      sym: :create,
      input_count: 3,
      output_count: 1,
      group: :system,
    },
    %{
      id: 0xf1,
      description: "Message-call into an account.,",
      sym: :call,
      input_count: 7,
      output_count: 1,
      group: :system,
    },
    %{
      id: 0xf2,
      description: "Message-call into this account with an alternative account’s code.,",
      sym: :callcode,
      input_count: 7,
      output_count: 1,
      group: :system,
    },
    %{
      id: 0xf3,
      description: "Halt execution returning output data,",
      sym: :return,
      input_count: 2,
      output_count: 0,
      group: :system,
    },
    %{
      id: 0xf4,
      description: "Message-call into this account with an alternative account’s code, but persisting the current values for sender and value.",
      sym: :delegatecall,
      input_count: 6,
      output_count: 1,
      group: :system,
    },
    %{
      id: 0xff,
      description: "Halt execution and register account for later deletion.",
      sym: :suicide,
      input_count: 1,
      output_count: 0,
      group: :system,
    }
  ], do: struct(EVM.Operation.Metadata, operation)

  def operations, do: @operations
end
