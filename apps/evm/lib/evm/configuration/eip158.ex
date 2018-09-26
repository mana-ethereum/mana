defmodule EVM.Configuration.EIP158 do
  @behaviour EVM.Configuration

  alias EVM.Configuration.EIP150

  defstruct fallback_config: EIP150.new(),
            exp_byte_cost: 50,
            code_size_limit: 24_577,
            increment_nonce_on_create: true,
            empty_account_value_transfer: true,
            clean_touched_accounts: true

  @type t :: %__MODULE__{}

  def new do
    %__MODULE__{}
  end

  @impl true
  def contract_creation_cost(config) do
    EIP150.contract_creation_cost(config.fallback_config)
  end

  @impl true
  def has_delegate_call?(config), do: EIP150.has_delegate_call?(config.fallback_config)

  @impl true
  def max_signature_s(config), do: EIP150.max_signature_s(config.fallback_config)

  @impl true
  def fail_contract_creation_lack_of_gas?(config) do
    EIP150.fail_contract_creation_lack_of_gas?(config.fallback_config)
  end

  @impl true
  def extcodesize_cost(config), do: EIP150.extcodesize_cost(config.fallback_config)

  @impl true
  def extcodecopy_cost(config), do: EIP150.extcodecopy_cost(config.fallback_config)

  @impl true
  def balance_cost(config), do: EIP150.balance_cost(config.fallback_config)

  @impl true
  def sload_cost(config), do: EIP150.sload_cost(config.fallback_config)

  @impl true
  def call_cost(config), do: EIP150.call_cost(config.fallback_config)

  @impl true
  def selfdestruct_cost(config, params) do
    EIP150.selfdestruct_cost(config.fallback_config, params)
  end

  @impl true
  def fail_nested_operation_lack_of_gas?(config) do
    EIP150.fail_nested_operation_lack_of_gas?(config.fallback_config)
  end

  @impl true
  def exp_byte_cost(config), do: config.exp_byte_cost

  @impl true
  def limit_contract_code_size?(config, size), do: size >= config.code_size_limit

  @impl true
  def increment_nonce_on_create?(config), do: config.increment_nonce_on_create

  @impl true
  def empty_account_value_transfer?(config), do: config.empty_account_value_transfer

  @impl true
  def clean_touched_accounts?(config), do: config.clean_touched_accounts

  @impl true
  def has_revert?(config), do: EIP150.has_revert?(config.fallback_config)

  @impl true
  def has_static_call?(config), do: EIP150.has_static_call?(config.fallback_config)

  @impl true
  def support_variable_length_return_value?(config) do
    EIP150.support_variable_length_return_value?(config.fallback_config)
  end

  @impl true
  def has_mod_exp_builtin?(config), do: EIP150.has_mod_exp_builtin?(config.fallback_config)

  @impl true
  def has_ec_add_builtin?(config), do: EIP150.has_ec_add_builtin?(config.fallback_config)

  @impl true
  def has_ec_mult_builtin?(config), do: EIP150.has_ec_mult_builtin?(config.fallback_config)

  @impl true
  def has_ec_pairing_builtin?(config) do
    EIP150.has_ec_pairing_builtin?(config.fallback_config)
  end

  @impl true
  def has_shift_operations?(config) do
    EIP150.has_shift_operations?(config.fallback_config)
  end

  @impl true
  def has_extcodehash?(config), do: EIP150.has_extcodehash?(config.fallback_config)

  @impl true
  def has_create2?(config), do: EIP150.has_create2?(config.fallback_config)

  @impl true
  def eip1283_sstore_gas_cost_changed?(config) do
    EIP150.eip1283_sstore_gas_cost_changed?(config.fallback_config)
  end
end
