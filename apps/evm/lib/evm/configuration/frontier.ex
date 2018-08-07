defmodule EVM.Configuration.Frontier do
  defstruct contract_creation_cost: 21_000,
            has_delegate_call: false,
            fail_contract_creation: false

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
end
