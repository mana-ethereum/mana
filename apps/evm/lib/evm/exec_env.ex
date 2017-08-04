defmodule EVM.ExecEnv do
  @moduledoc """
  Stores information about the execution environment which led
  to this EVM being called. This is, for instance, the sender of
  a payment or message to a contract, or a sub-contract call.

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
    block_header: nil,           # h
    stack_depth: nil]            # e

  @type t :: %__MODULE__{
    address: EVM.address,
    originator: EVM.address,
    gas_price: EVM.Gas.gas_price,
    data: binary(),
    sender: EVM.address,
    value_in_wei: EVM.Wei.t,
    machine_code: EVM.MachineCode.t,
    block_header: binary(),
    stack_depth: integer()
  }

  @doc """
  Returns the base execution environment for a message call.
  This is generally defined as equations 107-114 in the Yellow Paper.

  TODO: Machine code may be passed in as a hash
  TODO: How is block header passed in?

  # TODO: Examples
  """
  @spec exec_env_for_message_call(EVM.address, EVM.address, EVM.Gas.gas_price, binary(), EVM.address, EVM.Wei.t, integer(), binary(), EVM.MachineCode.t) :: t
  def exec_env_for_message_call(recipient, originator, gas_price, data, sender, value_in_wei, stack_depth, block_header, machine_code) do
    %__MODULE__{
      address: recipient,
      originator: originator,
      gas_price: gas_price,
      data: data,
      sender: sender,
      value_in_wei: value_in_wei,
      stack_depth: stack_depth,
      block_header: block_header,
      machine_code: machine_code,
    }
  end

end