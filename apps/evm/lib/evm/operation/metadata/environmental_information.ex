defmodule EVM.Operation.Metadata.EnvironmentalInformation do
  @operations for operation <- [
                    %{
                      id: 0x30,
                      description: "Get address of currently executing account.",
                      sym: :address,
                      input_count: 0,
                      output_count: 1,
                      group: :environmental_information
                    },
                    %{
                      id: 0x31,
                      description: "Get balance of the given account.",
                      sym: :balance,
                      input_count: 1,
                      output_count: 1,
                      group: :environmental_information
                    },
                    %{
                      id: 0x32,
                      sym: :origin,
                      description: "Get execution origination address.",
                      input_count: 0,
                      output_count: 1,
                      group: :environmental_information
                    },
                    %{
                      id: 0x33,
                      description: "Get caller address.",
                      sym: :caller,
                      input_count: 0,
                      output_count: 1,
                      group: :environmental_information
                    },
                    %{
                      id: 0x34,
                      description:
                        "Get deposited value by the operation/transaction responsible for this execution.",
                      sym: :callvalue,
                      input_count: 0,
                      output_count: 1,
                      group: :environmental_information
                    },
                    %{
                      id: 0x35,
                      description: "Get input data of current environment.",
                      sym: :calldataload,
                      input_count: 1,
                      output_count: 1,
                      group: :environmental_information
                    },
                    %{
                      id: 0x36,
                      description: "Get size of input data in current environment.",
                      sym: :calldatasize,
                      input_count: 0,
                      output_count: 1,
                      group: :environmental_information
                    },
                    %{
                      id: 0x37,
                      sym: :calldatacopy,
                      description: "Copy input data in current environment to memory.",
                      input_count: 3,
                      output_count: 0,
                      group: :environmental_information
                    },
                    %{
                      id: 0x38,
                      description: "Get size of code running in current environment.",
                      sym: :codesize,
                      input_count: 0,
                      output_count: 1,
                      group: :environmental_information
                    },
                    %{
                      id: 0x39,
                      description: "Copy code running in current environment to memory.",
                      sym: :codecopy,
                      input_count: 3,
                      output_count: 0,
                      group: :environmental_information
                    },
                    %{
                      id: 0x3A,
                      description: "Get price of gas in current environment.",
                      sym: :gasprice,
                      input_count: 0,
                      output_count: 1,
                      group: :environmental_information
                    },
                    %{
                      id: 0x3B,
                      description: "Get size of an account’s code.",
                      sym: :extcodesize,
                      input_count: 1,
                      output_count: 1,
                      group: :environmental_information
                    },
                    %{
                      id: 0x3C,
                      description: "Copy an account’s code to memory.",
                      sym: :extcodecopy,
                      input_count: 4,
                      output_count: 0,
                      group: :environmental_information
                    }
                  ],
                  do: struct(EVM.Operation.Metadata, operation)

  def operations, do: @operations
end
