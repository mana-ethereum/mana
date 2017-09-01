defprotocol EVM.Interface.ContractInterface do
  @moduledoc """
  Interface for interacting with a contract.
  """

  @type t :: module()

  @spec message_call(t, EVM.state, EVM.address, EVM.address, EVM.address, EVM.address, EVM.Gas.t, EVM.Gas.gas_price, EVM.Wei.t, EVM.Wei.t, binary(), integer(), Header.t) :: { EVM.state, EVM.Gas.t, EVM.SubState.t, EVM.VM.output }
  def message_call(t, state, sender, originator, recipient, contract, available_gas, gas_price, value, apparent_value, data, stack_depth, block_header)

end