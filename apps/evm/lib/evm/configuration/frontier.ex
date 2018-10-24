defmodule EVM.Configuration.Frontier do
  @behaviour EVM.Configuration

  defstruct contract_creation_cost: 21_000,
            has_delegate_call: false,
            should_fail_contract_creation_lack_of_gas: false,
            max_signature_s: :secp256k1n,
            extcodesize_cost: 20,
            extcodecopy_cost: 20,
            balance_cost: 20,
            sload_cost: 50,
            call_cost: 40,
            selfdestruct_cost: 0,
            should_fail_nested_operation_lack_of_gas: true,
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

  @impl true
  def new, do: %__MODULE__{}

  @impl true
  def selfdestruct_cost(config, _params), do: config.selfdestruct_cost

  @impl true
  def limit_contract_code_size?(config, _), do: config.limit_contract_code_size
end
