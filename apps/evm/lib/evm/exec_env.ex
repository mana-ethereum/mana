defmodule EVM.ExecEnv do
  @moduledoc """
  Stores information about the execution environment which led
  to this EVM being called. This is, for instance, the sender of
  a payment or message to a contract, or a sub-contract call.

  We've added our interfaces for interacting with contracts
  and accounts to this struct as well.

  This generally relates to `I` in the Yellow Paper, defined in
  Section 9.3.
  """

  defstruct [
    address: nil,                # a
    originator: nil,             # o
    gas_price: nil,              # p
    data: nil,                   # d
    sender: nil,                 # s
    value_in_wei: nil,           # v
    machine_code: <<>>,          # b
    stack_depth: 0,              # e
    block_interface: nil,        # h (wrapped in interface)
    account_interface: nil,
    contract_interface: nil,
  ]

  @type t :: %__MODULE__{
    address: EVM.address,
    originator: EVM.address,
    gas_price: EVM.Gas.gas_price,
    data: binary(),
    sender: EVM.address,
    value_in_wei: EVM.Wei.t,
    machine_code: EVM.MachineCode.t,
    stack_depth: integer(),
    block_interface: EVM.Interface.BlockInterface.t,
    account_interface: EVM.Interface.AccountInterface.t,
    contract_interface: EVM.Interface.ContractInterface.t,
  }

  @doc """
  Returns the base execution environment for a message call.
  This is generally defined as equations 107-114 in the Yellow Paper.

  TODO: Machine code may be passed in as a hash
  TODO: How is block header passed in?

  # TODO: Examples
  """
  @spec exec_env_for_message_call(EVM.address, EVM.address, EVM.Gas.gas_price, binary(), EVM.address, EVM.Wei.t, integer(), EVM.MachineCode.t, EVM.Interface.BlockInterface.t, EVM.Interface.AccountInterface.t, EVM.Interface.ContractInterface.t) :: t
  def exec_env_for_message_call(recipient, originator, gas_price, data, sender, value_in_wei, stack_depth, machine_code, block_interface, account_interface, contract_interface) do
    %__MODULE__{
      address: recipient,
      originator: originator,
      gas_price: gas_price,
      data: data,
      sender: sender,
      value_in_wei: value_in_wei,
      stack_depth: stack_depth,
      machine_code: machine_code,
      block_interface: block_interface,
      account_interface: account_interface,
      contract_interface: contract_interface,
    }
  end

end
