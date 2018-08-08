defmodule EVM.Configuration.EIP150 do
  defstruct extcodesize_cost: 700,
            extcodecopy_cost: 700,
            balance_cost: 400,
            sload_cost: 200,
            call_cost: 700,
            selfdestruct_cost: 5_000,
            new_account_destruction_cost: 25_000,
            fail_call_lack_of_gas: false,
            fallback_config: EVM.Configuration.Homestead.new()

  def new do
    %__MODULE__{}
  end
end

defimpl EVM.Configuration, for: EVM.Configuration.EIP150 do
  @spec contract_creation_cost(EVM.Configuration.t()) :: integer()
  def contract_creation_cost(config), do: config.fallback_config.contract_creation_cost

  @spec has_delegate_call?(EVM.Configuration.t()) :: boolean()
  def has_delegate_call?(config), do: config.fallback_config.has_delegate_call

  @spec fail_contract_creation_lack_of_gas?(EVM.Configuration.t()) :: boolean()
  def fail_contract_creation_lack_of_gas?(config),
    do: config.fallback_config.fail_contract_creation

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
  def selfdestruct_cost(config, new_account: false), do: config.selfdestruct_cost

  def selfdestruct_cost(config, new_account: true) do
    config.selfdestruct_cost + config.new_account_destruction_cost
  end

  @spec fail_call_lack_of_gas?(EVM.Configuration.t()) :: boolean()
  def fail_call_lack_of_gas?(config), do: config.fail_call_lack_of_gas
end
