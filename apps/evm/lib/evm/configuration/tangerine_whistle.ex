defmodule EVM.Configuration.TangerineWhistle do
  @behaviour EVM.Configuration

  alias EVM.Configuration.Homestead

  defstruct extcodesize_cost: 700,
            extcodecopy_cost: 700,
            balance_cost: 400,
            sload_cost: 200,
            call_cost: 700,
            selfdestruct_cost: 5_000,
            new_account_destruction_cost: 25_000,
            fail_nested_operation: false,
            fallback_config: Homestead.new()

  @type t :: %__MODULE__{}

  def new do
    %__MODULE__{}
  end

  @impl true
  def contract_creation_cost(config), do: config.fallback_config.contract_creation_cost

  @impl true
  def has_delegate_call?(config), do: config.fallback_config.has_delegate_call

  @impl true
  def max_signature_s(config), do: Homestead.max_signature_s(config.fallback_config)

  @impl true
  def fail_contract_creation_lack_of_gas?(config) do
    config.fallback_config.fail_contract_creation
  end

  @impl true
  def extcodesize_cost(config), do: config.extcodesize_cost

  @impl true
  def extcodecopy_cost(config), do: config.extcodecopy_cost

  @impl true
  def balance_cost(config), do: config.balance_cost

  @impl true
  def sload_cost(config), do: config.sload_cost

  @impl true
  def call_cost(config), do: config.call_cost

  @impl true
  def selfdestruct_cost(config, new_account: false), do: config.selfdestruct_cost

  def selfdestruct_cost(config, new_account: true) do
    config.selfdestruct_cost + config.new_account_destruction_cost
  end

  @impl true
  def fail_nested_operation_lack_of_gas?(config), do: config.fail_nested_operation

  @impl true
  def exp_byte_cost(config), do: Homestead.exp_byte_cost(config.fallback_config)

  @impl true
  def limit_contract_code_size?(config, size) do
    Homestead.limit_contract_code_size?(config.fallback_config, size)
  end

  @impl true
  def increment_nonce_on_create?(config) do
    Homestead.increment_nonce_on_create?(config.fallback_config)
  end

  @impl true
  def empty_account_value_transfer?(config) do
    Homestead.empty_account_value_transfer?(config.fallback_config)
  end

  @impl true
  def clean_touched_accounts?(config) do
    Homestead.clean_touched_accounts?(config.fallback_config)
  end

  @impl true
  def has_revert?(config), do: Homestead.has_revert?(config.fallback_config)

  @impl true
  def has_static_call?(config), do: Homestead.has_static_call?(config.fallback_config)

  @impl true
  def support_variable_length_return_value?(config) do
    Homestead.support_variable_length_return_value?(config.fallback_config)
  end

  @impl true
  def has_mod_exp_builtin?(config), do: Homestead.has_mod_exp_builtin?(config.fallback_config)

  @impl true
  def has_ec_add_builtin?(config), do: Homestead.has_ec_add_builtin?(config.fallback_config)

  @impl true
  def has_ec_mult_builtin?(config), do: Homestead.has_ec_mult_builtin?(config.fallback_config)

  @impl true
  def has_ec_pairing_builtin?(config) do
    Homestead.has_ec_pairing_builtin?(config.fallback_config)
  end

  @impl true
  def has_shift_operations?(config) do
    Homestead.has_shift_operations?(config.fallback_config)
  end

  @impl true
  def has_extcodehash?(config), do: Homestead.has_extcodehash?(config.fallback_config)

  @impl true
  def has_create2?(config), do: Homestead.has_create2?(config.fallback_config)

  @impl true
  def eip1283_sstore_gas_cost_changed?(config) do
    Homestead.eip1283_sstore_gas_cost_changed?(config.fallback_config)
  end
end
