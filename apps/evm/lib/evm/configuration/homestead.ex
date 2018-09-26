defmodule EVM.Configuration.Homestead do
  @behaviour EVM.Configuration

  alias EVM.Configuration.Frontier

  defstruct contract_creation_cost: 53_000,
            has_delegate_call: true,
            max_signature_s: :secp256k1n_2,
            fail_contract_creation: true,
            fallback_config: Frontier.new()

  @type t :: %__MODULE__{}

  def new do
    %__MODULE__{}
  end

  @impl true
  def contract_creation_cost(config), do: config.contract_creation_cost

  @impl true
  def has_delegate_call?(config), do: config.has_delegate_call

  @impl true
  def max_signature_s(config), do: config.max_signature_s

  @impl true
  def fail_contract_creation_lack_of_gas?(config), do: config.fail_contract_creation

  @impl true
  def extcodesize_cost(config), do: Frontier.extcodesize_cost(config.fallback_config)

  @impl true
  def extcodecopy_cost(config), do: Frontier.extcodecopy_cost(config.fallback_config)

  @impl true
  def balance_cost(config), do: Frontier.balance_cost(config.fallback_config)

  @impl true
  def sload_cost(config), do: Frontier.sload_cost(config.fallback_config)

  @impl true
  def call_cost(config), do: Frontier.call_cost(config.fallback_config)

  @impl true
  def selfdestruct_cost(config, params) do
    Frontier.selfdestruct_cost(config.fallback_config, params)
  end

  @impl true
  def fail_nested_operation_lack_of_gas?(config) do
    Frontier.fail_nested_operation_lack_of_gas?(config.fallback_config)
  end

  @impl true
  def exp_byte_cost(config), do: Frontier.exp_byte_cost(config.fallback_config)

  @impl true
  def limit_contract_code_size?(config, size) do
    Frontier.limit_contract_code_size?(config.fallback_config, size)
  end

  @impl true
  def increment_nonce_on_create?(config) do
    Frontier.increment_nonce_on_create?(config.fallback_config)
  end

  @impl true
  def empty_account_value_transfer?(config) do
    Frontier.empty_account_value_transfer?(config.fallback_config)
  end

  @impl true
  def clean_touched_accounts?(config) do
    Frontier.clean_touched_accounts?(config.fallback_config)
  end

  @impl true
  def has_revert?(config), do: Frontier.has_revert?(config.fallback_config)

  @impl true
  def has_static_call?(config), do: Frontier.has_static_call?(config.fallback_config)

  @impl true
  def support_variable_length_return_value?(config) do
    Frontier.support_variable_length_return_value?(config.fallback_config)
  end

  @impl true
  def has_mod_exp_builtin?(config), do: Frontier.has_mod_exp_builtin?(config.fallback_config)

  @impl true
  def has_ec_add_builtin?(config), do: Frontier.has_ec_add_builtin?(config.fallback_config)

  @impl true
  def has_ec_mult_builtin?(config), do: Frontier.has_ec_mult_builtin?(config.fallback_config)

  @impl true
  def has_ec_pairing_builtin?(config) do
    Frontier.has_ec_pairing_builtin?(config.fallback_config)
  end

  @impl true
  def has_shift_operations?(config) do
    Frontier.has_shift_operations?(config.fallback_config)
  end

  @impl true
  def has_extcodehash?(config), do: Frontier.has_extcodehash?(config.fallback_config)

  @impl true
  def has_create2?(config), do: Frontier.has_create2?(config.fallback_config)

  @impl true
  def eip1283_sstore_gas_cost_changed?(config) do
    Frontier.eip1283_sstore_gas_cost_changed?(config.fallback_config)
  end
end
