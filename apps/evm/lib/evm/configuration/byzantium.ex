defmodule EVM.Configuration.Byzantium do
  alias EVM.Configuration.SpuriousDragon

  use EVM.Configuration,
    fallback_config: SpuriousDragon,
    overrides: %{
      has_revert: true,
      has_static_call: true,
      support_variable_length_return_value: true,
      has_mod_exp_builtin: true,
      status_in_receipt: true,
      has_ec_add_builtin: true,
      has_ec_mult_builtin: true,
      has_ec_pairing_builtin: true
    }

  @impl true
  def selfdestruct_cost(config, params) do
    SpuriousDragon.selfdestruct_cost(config, params)
  end

  @impl true
  def limit_contract_code_size?(config, size) do
    SpuriousDragon.limit_contract_code_size?(config, size)
  end
end
