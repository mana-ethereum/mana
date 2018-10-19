defmodule EVM.Configuration.Frontier do
  @behaviour EVM.Configuration

  defstruct contract_creation_cost: 21_000,
            has_delegate_call: false,
            fail_contract_creation: false,
            max_signature_s: :secp256k1n,
            extcodesize_cost: 20,
            extcodecopy_cost: 20,
            balance_cost: 20,
            sload_cost: 50,
            call_cost: 40,
            selfdestruct_cost: 0,
            fail_nested_operation: true,
            exp_byte_cost: 10,
            limit_contract_code_size: false,
            increment_nonce_on_create: false,
            empty_account_value_transfer: false,
            clean_touched_accounts: false,
            has_revert: false,
            has_static_call: false,
            support_variable_length_return_value: false,
            has_mod_exp_builtin: false,
            status_in_receipt: false,
            has_ec_add_builtin: false,
            has_ec_mult_builtin: false,
            has_ec_pairing_builtin: false,
            has_shift_operations: false,
            has_extcodehash: false,
            has_create2: false,
            eip1283_sstore_gas_cost_changed: false

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
  def selfdestruct_cost(config, _params), do: config.selfdestruct_cost

  @impl true
  def fail_nested_operation_lack_of_gas?(config), do: config.fail_nested_operation

  @impl true
  def exp_byte_cost(config), do: config.exp_byte_cost

  @impl true
  def limit_contract_code_size?(config, _), do: config.limit_contract_code_size

  @impl true
  def increment_nonce_on_create?(config), do: config.increment_nonce_on_create

  @impl true
  def empty_account_value_transfer?(config), do: config.empty_account_value_transfer

  @impl true
  def clean_touched_accounts?(config), do: config.clean_touched_accounts

  @impl true
  def has_revert?(config), do: config.has_revert

  @impl true
  def has_static_call?(config), do: config.has_static_call

  @impl true
  def support_variable_length_return_value?(config),
    do: config.support_variable_length_return_value

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
  def has_shift_operations?(config), do: config.has_shift_operations

  @impl true
  def has_extcodehash?(config), do: config.has_extcodehash

  @impl true
  def has_create2?(config), do: config.has_create2

  @impl true
  def eip1283_sstore_gas_cost_changed?(config), do: config.eip1283_sstore_gas_cost_changed
end
