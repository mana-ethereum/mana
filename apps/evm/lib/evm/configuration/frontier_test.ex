defmodule EVM.Configuration.FrontierTest do
  defstruct contract_creation_cost: 21_000, has_delegate_call: false

  def new do
    %__MODULE__{}
  end
end

defimpl EVM.Configuration, for: EVM.Configuration.FrontierTest do
  @spec contract_creation_cost(EVM.Configuration.t()) :: integer()
  def contract_creation_cost(config), do: config.contract_creation_cost

  @spec has_delegate_call?(EVM.Configuration.t()) :: boolean()
  def has_delegate_call?(config), do: config.has_delegate_call
end
