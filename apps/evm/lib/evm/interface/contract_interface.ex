defprotocol EVM.Interface.ContractInterface do
  @moduledoc """
  Interface for interacting with a contract.
  """

  @type t :: module()

  @spec message_call(t, EVM.address, EVM.address, EVM.address, EVM.address, EVM.Gas.t, EVM.Gas.gas_price, EVM.Wei.t, EVM.Wei.t, binary(), integer(), Header.t) :: { EVM.state, EVM.Gas.t, EVM.SubState.t, EVM.VM.output }
  def message_call(t, sender, originator, recipient, contract, available_gas, gas_price, value, apparent_value, data, stack_depth, block_header)

  @spec create_contract(t, EVM.address, EVM.address, EVM.Gas.t, EVM.Gas.gas_price, EVM.Wei.t, EVM.MachineCode.t, integer(), Header.t) :: { EVM.state, EVM.Gas.t, EVM.SubState.t }
  def create_contract(t, sender, originator, available_gas, gas_price, endowment, init_code, stack_depth, block_header)

  @spec new_contract_address(t, EVM.address, integer()) :: EVM.address
  def new_contract_address(t, address, nonce)

end
