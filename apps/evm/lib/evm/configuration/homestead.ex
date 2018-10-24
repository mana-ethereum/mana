defmodule EVM.Configuration.Homestead do
  alias EVM.Configuration.Frontier

  use EVM.Configuration,
    fallback_config: Frontier,
    overrides: %{
      contract_creation_cost: 53_000,
      has_delegate_call: true,
      max_signature_s: :secp256k1n_2,
      should_fail_contract_creation_lack_of_gas: true
    }

  @impl true
  def selfdestruct_cost(config, _params) do
    config.selfdestruct_cost
  end

  @impl true
  def limit_contract_code_size?(config, _size) do
    config.limit_contract_code_size
  end
end
