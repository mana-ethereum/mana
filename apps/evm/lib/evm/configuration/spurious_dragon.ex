defmodule EVM.Configuration.SpuriousDragon do
  @behaviour EVM.Configuration

  alias EVM.Configuration.TangerineWhistle

  defstruct fallback_config: TangerineWhistle.new(),
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
    TangerineWhistle.contract_creation_cost(config.fallback_config)
  end

  @impl true
  def has_delegate_call?(config), do: TangerineWhistle.has_delegate_call?(config.fallback_config)

  @impl true
  def max_signature_s(config), do: TangerineWhistle.max_signature_s(config.fallback_config)

  @impl true
  def fail_contract_creation_lack_of_gas?(config) do
    TangerineWhistle.fail_contract_creation_lack_of_gas?(config.fallback_config)
  end

  @impl true
  def extcodesize_cost(config), do: TangerineWhistle.extcodesize_cost(config.fallback_config)

  @impl true
  def extcodecopy_cost(config), do: TangerineWhistle.extcodecopy_cost(config.fallback_config)

  @impl true
  def balance_cost(config), do: TangerineWhistle.balance_cost(config.fallback_config)

  @impl true
  def sload_cost(config), do: TangerineWhistle.sload_cost(config.fallback_config)

  @impl true
  def call_cost(config), do: TangerineWhistle.call_cost(config.fallback_config)

  @impl true
  def selfdestruct_cost(config, params) do
    TangerineWhistle.selfdestruct_cost(config.fallback_config, params)
  end

  @impl true
  def fail_nested_operation_lack_of_gas?(config) do
    TangerineWhistle.fail_nested_operation_lack_of_gas?(config.fallback_config)
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
  def has_revert?(config), do: TangerineWhistle.has_revert?(config.fallback_config)

  @impl true
  def has_static_call?(config), do: TangerineWhistle.has_static_call?(config.fallback_config)

  @impl true
  def support_variable_length_return_value?(config) do
    TangerineWhistle.support_variable_length_return_value?(config.fallback_config)
  end

  @impl true
  def has_mod_exp_builtin?(config),
    do: TangerineWhistle.has_mod_exp_builtin?(config.fallback_config)

  @impl true
  def status_in_receipt?(config),
    do: TangerineWhistle.status_in_receipt?(config.fallback_config)

  @impl true
  def has_ec_add_builtin?(config),
    do: TangerineWhistle.has_ec_add_builtin?(config.fallback_config)

  @impl true
  def has_ec_mult_builtin?(config),
    do: TangerineWhistle.has_ec_mult_builtin?(config.fallback_config)

  @impl true
  def has_ec_pairing_builtin?(config) do
    TangerineWhistle.has_ec_pairing_builtin?(config.fallback_config)
  end

  @impl true
  def has_shift_operations?(config) do
    TangerineWhistle.has_shift_operations?(config.fallback_config)
  end

  @impl true
  def has_extcodehash?(config), do: TangerineWhistle.has_extcodehash?(config.fallback_config)

  @impl true
  def has_create2?(config), do: TangerineWhistle.has_create2?(config.fallback_config)

  @impl true
  def eip1283_sstore_gas_cost_changed?(config) do
    TangerineWhistle.eip1283_sstore_gas_cost_changed?(config.fallback_config)
  end
end
