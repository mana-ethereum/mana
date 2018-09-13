defmodule EVM.Operation.Metadata.System do
  @operations for operation <- [
                    %{
                      id: 0xF0,
                      description: "Create a new account with associated code.",
                      sym: :create,
                      input_count: 3,
                      output_count: 1,
                      group: :system
                    },
                    %{
                      id: 0xF1,
                      description: "Message-call into an account.,",
                      sym: :call,
                      input_count: 7,
                      output_count: 1,
                      group: :system
                    },
                    %{
                      id: 0xF2,
                      description:
                        "Message-call into this account with an alternative account’s code.,",
                      sym: :callcode,
                      input_count: 7,
                      output_count: 1,
                      group: :system
                    },
                    %{
                      id: 0xF3,
                      description: "Halt execution returning output data,",
                      sym: :return,
                      input_count: 2,
                      output_count: 0,
                      group: :system
                    },
                    %{
                      id: 0xF4,
                      description:
                        "Message-call into this account with an alternative account’s code,
                          but persisting the current values for sender and value.",
                      sym: :delegatecall,
                      input_count: 6,
                      output_count: 1,
                      group: :system
                    },
                    %{
                      id: 0xF5,
                      description: "Skinny CREATE2. EIP-1014",
                      sym: :create2,
                      input_count: 4,
                      output_count: 1,
                      group: :system
                    },
                    %{
                      id: 0xFA,
                      description: "Static message-call into an account",
                      sym: :staticcall,
                      input_count: 6,
                      output_count: 1,
                      group: :system
                    },
                    %{
                      id: 0xFD,
                      description:
                        "Halt execution reverting state changes but returning data and remaining gas.",
                      sym: :revert,
                      input_count: 2,
                      output_count: 0,
                      group: :system
                    },
                    %{
                      id: 0xFE,
                      description:
                        "Designated invalid instruction. It can be used to abort the execution.",
                      sym: :invalid,
                      input_count: 0,
                      output_count: 0,
                      group: :system
                    }
                  ],
                  do: struct(EVM.Operation.Metadata, operation)

  def operations, do: @operations
end
