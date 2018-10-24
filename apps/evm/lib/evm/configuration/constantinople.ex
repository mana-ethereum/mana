defmodule EVM.Configuration.Constantinople do
  alias EVM.Configuration.Byzantium

  use EVM.Configuration,
    fallback_config: Byzantium,
    overrides: %{
      has_shift_operations: true,
      has_extcodehash: true,
      has_create2: true,
      eip1283_sstore_gas_cost_changed: true
    }

  @impl true
  def selfdestruct_cost(config, params) do
    Byzantium.selfdestruct_cost(config, params)
  end

  @impl true
  def limit_contract_code_size?(config, size) do
    Byzantium.limit_contract_code_size?(config, size)
  end
end
