defmodule EVM.Configuration.Byzantium do
  @behaviour EVM.Configuration

  alias EVM.Configuration.EIP158

  defstruct fallback_config: EIP158.new(),
            has_revert: true,
            has_static_call: true,
            support_variable_length_return_value: true,
            has_mod_exp_builtin: true,
            has_ec_add_builtin: true,
            has_ec_mult_builtin: true,
            has_ec_pairing_builtin: true

  @type t :: %__MODULE__{}

  def new do
    %__MODULE__{}
  end

  @impl true
  def contract_creation_cost(config) do
    EIP158.contract_creation_cost(config.fallback_config)
  end

  @impl true
  def has_delegate_call?(config), do: EIP158.has_delegate_call?(config.fallback_config)

  @impl true
  def max_signature_s(config), do: EIP158.max_signature_s(config.fallback_config)

  @impl true
  def fail_contract_creation_lack_of_gas?(config) do
    EIP158.fail_contract_creation_lack_of_gas?(config.fallback_config)
  end

  @impl true
  def extcodesize_cost(config), do: EIP158.extcodesize_cost(config.fallback_config)

  @impl true
  def extcodecopy_cost(config), do: EIP158.extcodecopy_cost(config.fallback_config)

  @impl true
  def balance_cost(config), do: EIP158.balance_cost(config.fallback_config)

  @impl true
  def sload_cost(config), do: EIP158.sload_cost(config.fallback_config)

  @impl true
  def call_cost(config), do: EIP158.call_cost(config.fallback_config)

  @impl true
  def selfdestruct_cost(config, params) do
    EIP158.selfdestruct_cost(config.fallback_config, params)
  end

  @impl true
  def fail_nested_operation_lack_of_gas?(config) do
    EIP158.fail_nested_operation_lack_of_gas?(config.fallback_config)
  end

  @impl true
  def exp_byte_cost(config), do: EIP158.exp_byte_cost(config.fallback_config)

  @impl true
  def limit_contract_code_size?(config, size) do
    EIP158.limit_contract_code_size?(config.fallback_config, size)
  end

  @impl true
  def increment_nonce_on_create?(config) do
    EIP158.increment_nonce_on_create?(config.fallback_config)
  end

  @impl true
  def empty_account_value_transfer?(config) do
    EIP158.empty_account_value_transfer?(config.fallback_config)
  end

  @impl true
  def clean_touched_accounts?(config) do
    EIP158.clean_touched_accounts?(config.fallback_config)
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
  def has_ec_add_builtin?(config), do: config.has_ec_add_builtin

  @impl true
  def has_ec_mult_builtin?(config), do: config.has_ec_mult_builtin

  @impl true
  def has_ec_pairing_builtin?(config), do: config.has_ec_pairing_builtin

  @impl true
  def has_shift_operations?(config) do
    EIP158.has_shift_operations?(config.fallback_config)
  end

  @impl true
  def has_extcodehash?(config), do: EIP158.has_extcodehash?(config.fallback_config)

  @impl true
  def has_create2?(config), do: EIP158.has_create2?(config.fallback_config)

  @impl true
  def eip1283_sstore_gas_cost_changed?(config) do
    EIP158.eip1283_sstore_gas_cost_changed?(config.fallback_config)
  end
end
