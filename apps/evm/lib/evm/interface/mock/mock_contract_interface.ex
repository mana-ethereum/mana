defmodule EVM.Interface.Mock.MockContractInterface do
  @moduledoc """
  Simple implementation of a contract interface.
  """

  defstruct [
    state: nil,
    gas: nil,
    sub_state: nil,
    output: nil
  ]

  def new(state, gas, sub_state, output) do
    %__MODULE__{
      state: state,
      gas: gas,
      sub_state: sub_state,
      output: output
    }
  end

end

defimpl EVM.Interface.ContractInterface, for: EVM.Interface.Mock.MockContractInterface do

  @spec message_call(EVM.Interface.ContractInterface.t, EVM.state, EVM.address, EVM.address, EVM.address, EVM.address, EVM.Gas.t, EVM.Gas.gas_price, EVM.Wei.t, EVM.Wei.t, binary(), integer(), Header.t) :: { EVM.state, EVM.Gas.t, EVM.SubState.t, EVM.VM.output }
  def message_call(mock_contract_interface, _state, _sender, _originator, _recipient, _contract, _available_gas, _gas_price, _value, _apparent_value, _data, _stack_depth, _block_header) do
    {
      mock_contract_interface.state,
      mock_contract_interface.gas,
      mock_contract_interface.sub_state,
      mock_contract_interface.output
    }
  end

  @spec create_contract(EVM.Interface.ContractInterface.t, EVM.state, EVM.address, EVM.address, EVM.Gas.t, EVM.Gas.gas_price, EVM.Wei.t, EVM.MachineCode.t, integer(), Header.t) :: { EVM.state, EVM.Gas.t, EVM.SubState.t }
  def create_contract(mock_contract_interface, _state, _sender, _originator, _available_gas, _gas_price, _endowment, _init_code, _stack_depth, _block_header) do
    {
      mock_contract_interface.state,
      mock_contract_interface.gas,
      mock_contract_interface.sub_state
    }
  end

  @spec new_contract_address(EVM.Interface.ContractInterface.t, EVM.address, integer()) :: EVM.address
  def new_contract_address(_mock_contract_interface, address, _nonce) do
    address
  end

end