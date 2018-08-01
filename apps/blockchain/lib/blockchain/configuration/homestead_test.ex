defmodule Blockchain.Configuration.HomesteadTest do
  defstruct contract_creation_cost: 53_000, has_static_call: true

  def new do
    %__MODULE__{}
  end
end

defimpl EVM.Configuration, for: Blockchain.Configuration.HomesteadTest do
  @spec contract_creation_cost(EVM.Configuration.t()) :: integer()
  def contract_creation_cost(config), do: config.contract_creation_cost

  @spec has_static_call?(EVM.Configuration.t()) :: boolean()
  def has_static_call?(config), do: config.has_static_call
end
