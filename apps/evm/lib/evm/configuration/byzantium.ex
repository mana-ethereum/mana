defmodule EVM.Configuration.Byzantium do
  @behaviour EVM.Configuration

  alias EVM.Configuration.SpuriousDragon

  defstruct fallback_config: SpuriousDragon.new(),
            has_revert: true,
            has_static_call: true,
            support_variable_length_return_value: true,
            has_mod_exp_builtin: true,
            status_in_receipt: true,
            has_ec_add_builtin: true,
            has_ec_mult_builtin: true,
            has_ec_pairing_builtin: true

  @type t :: %__MODULE__{}

  def new do
    %__MODULE__{}
  end

  @impl true
  def contract_creation_cost(config) do
    SpuriousDragon.contract_creation_cost(config.fallback_config)
  end

  @impl true
  def has_delegate_call?(config), do: SpuriousDragon.has_delegate_call?(config.fallback_config)

  @impl true
  def max_signature_s(config), do: SpuriousDragon.max_signature_s(config.fallback_config)

  @impl true
  def fail_contract_creation_lack_of_gas?(config) do
    SpuriousDragon.fail_contract_creation_lack_of_gas?(config.fallback_config)
  end

  @impl true
  def extcodesize_cost(config), do: SpuriousDragon.extcodesize_cost(config.fallback_config)

  @impl true
  def extcodecopy_cost(config), do: SpuriousDragon.extcodecopy_cost(config.fallback_config)

  @impl true
  def balance_cost(config), do: SpuriousDragon.balance_cost(config.fallback_config)

  @impl true
  def sload_cost(config), do: SpuriousDragon.sload_cost(config.fallback_config)

  @impl true
  def call_cost(config), do: SpuriousDragon.call_cost(config.fallback_config)

  @impl true
  def selfdestruct_cost(config, params) do
    SpuriousDragon.selfdestruct_cost(config.fallback_config, params)
  end

  @impl true
  def fail_nested_operation_lack_of_gas?(config) do
    SpuriousDragon.fail_nested_operation_lack_of_gas?(config.fallback_config)
  end

  @impl true
  def exp_byte_cost(config), do: SpuriousDragon.exp_byte_cost(config.fallback_config)

  @impl true
  def limit_contract_code_size?(config, size) do
    SpuriousDragon.limit_contract_code_size?(config.fallback_config, size)
  end

  @impl true
  def increment_nonce_on_create?(config) do
    SpuriousDragon.increment_nonce_on_create?(config.fallback_config)
  end

  @impl true
  def empty_account_value_transfer?(config) do
    SpuriousDragon.empty_account_value_transfer?(config.fallback_config)
  end

  @impl true
  def clean_touched_accounts?(config) do
    SpuriousDragon.clean_touched_accounts?(config.fallback_config)
  end

  @impl true
  def has_revert?(config), do: config.has_revert

  @impl true
  def has_static_call?(config), do: config.has_static_call

  @impl true
  def support_variable_length_return_value?(config) do
    config.support_variable_length_return_value
  end

  @impl true
  def has_mod_exp_builtin?(config), do: config.has_mod_exp_builtin

  @impl true
  def status_in_receipt?(config), do: config.status_in_receipt

  @impl true
  def has_ec_add_builtin?(config), do: config.has_ec_add_builtin

  @impl true
  def has_ec_mult_builtin?(config), do: config.has_ec_mult_builtin

  @impl true
  def has_ec_pairing_builtin?(config), do: config.has_ec_pairing_builtin

  @impl true
  def has_shift_operations?(config) do
    SpuriousDragon.has_shift_operations?(config.fallback_config)
  end

  @impl true
  def has_extcodehash?(config), do: SpuriousDragon.has_extcodehash?(config.fallback_config)

  @impl true
  def has_create2?(config), do: SpuriousDragon.has_create2?(config.fallback_config)

  @impl true
  def eip1283_sstore_gas_cost_changed?(config) do
    SpuriousDragon.eip1283_sstore_gas_cost_changed?(config.fallback_config)
  end
end
