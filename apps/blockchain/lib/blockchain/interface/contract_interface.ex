defmodule Blockchain.Interface.ContractInterface do
  @moduledoc """
  Defines an interface for methods to interact with contracts.
  """

  @type t :: %__MODULE__{}

  defstruct []

  @doc """
  Returns a new contract interface.

  ## Examples

      iex> Blockchain.Interface.ContractInterface.new()
      %Blockchain.Interface.ContractInterface{}
  """
  def new() do
    %__MODULE__{}
  end
end

defimpl EVM.Interface.ContractInterface, for: Blockchain.Interface.ContractInterface do

  # TODO: Add test case
  @spec message_call(EVM.Interface.ContractInterface.t, EVM.state, EVM.address, EVM.address, EVM.address, EVM.address, EVM.Gas.t, EVM.Gas.gas_price, EVM.Wei.t, EVM.Wei.t, binary(), integer(), Header.t) :: { EVM.state, EVM.Gas.t, EVM.SubState.t, EVM.VM.output }
  def message_call(_contract_interface, state, sender, originator, recipient, contract, available_gas, gas_price, value, apparent_value, data, stack_depth, block_header) do
    Blockchain.Contract.message_call(state, sender, originator, recipient, contract, available_gas, gas_price, value, apparent_value, data, stack_depth, block_header)
  end

  # TODO: Add test case
  @spec create_contract(EVM.Interface.ContractInterface.t, EVM.state, EVM.address, EVM.address, EVM.Gas.t, EVM.Gas.gas_price, EVM.Wei.t, EVM.MachineCode.t, integer(), Header.t) :: { EVM.state, EVM.Gas.t, EVM.SubState.t }
  def create_contract(_contract_interface, state, sender, originator, available_gas, gas_price, endowment, init_code, stack_depth, block_header) do
    Blockchain.Contract.create_contract(state, sender, originator, available_gas, gas_price, endowment, init_code, stack_depth, block_header)
  end

  # TODO: Add test case
  @spec new_contract_address(EVM.Interface.ContractInterface.t, EVM.address, integer()) :: EVM.address
  def new_contract_address(_contract_interface, address, nonce) do
    Blockchain.Contract.new_contract_address(address, nonce)
  end

end