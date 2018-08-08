defmodule EVM.Configuration.Frontier do
  defstruct contract_creation_cost: 21_000,
            has_delegate_call: false,
            fail_contract_creation: false,
            extcodesize_cost: 20,
            extcodecopy_cost: 20,
            balance_cost: 20,
            sload_cost: 50,
            call_cost: 40,
            selfdestruct_cost: 0

  def new do
    %__MODULE__{}
  end
end

defimpl EVM.Configuration, for: EVM.Configuration.Frontier do
  @spec contract_creation_cost(EVM.Configuration.t()) :: integer()
  def contract_creation_cost(config), do: config.contract_creation_cost

  @spec has_delegate_call?(EVM.Configuration.t()) :: boolean()
  def has_delegate_call?(config), do: config.has_delegate_call

  @spec fail_contract_creation_lack_of_gas?(EVM.Configuration.t()) :: boolean()
  def fail_contract_creation_lack_of_gas?(config), do: config.fail_contract_creation

  @spec extcodesize_cost(EVM.Configuration.t()) :: integer()
  def extcodesize_cost(config), do: config.extcodesize_cost

  @spec extcodecopy_cost(EVM.Configuration.t()) :: integer()
  def extcodecopy_cost(config), do: config.extcodecopy_cost

  @spec balance_cost(EVM.Configuration.t()) :: integer()
  def balance_cost(config), do: config.balance_cost

  @spec sload_cost(EVM.Configuration.t()) :: integer()
  def sload_cost(config), do: config.sload_cost

  @spec call_cost(EVM.Configuration.t()) :: integer()
  def call_cost(config), do: config.call_cost

  @spec selfdestruct_cost(EVM.Configuration.t(), keyword()) :: integer()
  def selfdestruct_cost(config, _params), do: config.selfdestruct_cost
end
