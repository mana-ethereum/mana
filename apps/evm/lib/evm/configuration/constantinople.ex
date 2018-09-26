defmodule EVM.Configuration.Constantinople do
  @behaviour EVM.Configuration

  alias EVM.Configuration.Byzantium

  defstruct fallback_config: Byzantium.new(),
            has_shift_operations: true,
            has_extcodehash: true,
            has_create2: true,
            # temporarily disabled (no common tests yet) https://github.com/ethereum/tests/issues/483
            eip1283_sstore_gas_cost_changed: false

  @type t :: %__MODULE__{}

  def new do
    %__MODULE__{}
  end

  @impl true
  def contract_creation_cost(config) do
    Byzantium.contract_creation_cost(config.fallback_config)
  end

  @impl true
  def has_delegate_call?(config), do: Byzantium.has_delegate_call?(config.fallback_config)

  @impl true
  def max_signature_s(config), do: Byzantium.max_signature_s(config.fallback_config)

  @impl true
  def fail_contract_creation_lack_of_gas?(config) do
    Byzantium.fail_contract_creation_lack_of_gas?(config.fallback_config)
  end

  @impl true
  def extcodesize_cost(config), do: Byzantium.extcodesize_cost(config.fallback_config)

  @impl true
  def extcodecopy_cost(config), do: Byzantium.extcodecopy_cost(config.fallback_config)

  @impl true
  def balance_cost(config), do: Byzantium.balance_cost(config.fallback_config)

  @impl true
  def sload_cost(config), do: Byzantium.sload_cost(config.fallback_config)

  @impl true
  def call_cost(config), do: Byzantium.call_cost(config.fallback_config)

  @impl true
  def selfdestruct_cost(config, params) do
    Byzantium.selfdestruct_cost(config.fallback_config, params)
  end

  @impl true
  def fail_nested_operation_lack_of_gas?(config) do
    Byzantium.fail_nested_operation_lack_of_gas?(config.fallback_config)
  end

  @impl true
  def exp_byte_cost(config), do: Byzantium.exp_byte_cost(config.fallback_config)

  @impl true
  def limit_contract_code_size?(config, size) do
    Byzantium.limit_contract_code_size?(config.fallback_config, size)
  end

  @impl true
  def increment_nonce_on_create?(config) do
    Byzantium.increment_nonce_on_create?(config.fallback_config)
  end

  @impl true
  def empty_account_value_transfer?(config) do
    Byzantium.empty_account_value_transfer?(config.fallback_config)
  end

  @impl true
  def clean_touched_accounts?(config) do
    Byzantium.clean_touched_accounts?(config.fallback_config)
  end

  @impl true
  def has_revert?(config), do: Byzantium.has_revert?(config.fallback_config)

  @impl true
  def has_static_call?(config), do: Byzantium.has_static_call?(config.fallback_config)

  @impl true
  def support_variable_length_return_value?(config) do
    Byzantium.support_variable_length_return_value?(config.fallback_config)
  end

  @impl true
  def has_mod_exp_builtin?(config), do: Byzantium.has_mod_exp_builtin?(config.fallback_config)

  @impl true
  def has_ec_add_builtin?(config), do: Byzantium.has_ec_add_builtin?(config.fallback_config)

  @impl true
  def has_ec_mult_builtin?(config), do: Byzantium.has_ec_mult_builtin?(config.fallback_config)

  @impl true
  def has_ec_pairing_builtin?(config) do
    Byzantium.has_ec_pairing_builtin?(config.fallback_config)
  end

  @impl true
  def has_shift_operations?(config) do
    config.has_shift_operations
  end

  @impl true
  def has_extcodehash?(config), do: config.has_extcodehash

  @impl true
  def has_create2?(config), do: config.has_create2

  @impl true
  def eip1283_sstore_gas_cost_changed?(config) do
    config.eip1283_sstore_gas_cost_changed
  end
end
