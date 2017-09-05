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

end