defmodule EVM.Configuration.Frontier do
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
            has_ec_add_builtin: false,
            has_ec_mult_builtin: false,
            has_ec_pairing_builtin: false,
            has_shift_operations: false,
            has_extcodehash: false,
            has_create2: false

  def new do
    %__MODULE__{}
  end
end

defimpl EVM.Configuration, for: EVM.Configuration.Frontier do
  alias EVM.Configuration

  @spec contract_creation_cost(Configuration.t()) :: integer()
  def contract_creation_cost(config), do: config.contract_creation_cost

  @spec has_delegate_call?(Configuration.t()) :: boolean()
  def has_delegate_call?(config), do: config.has_delegate_call

  @spec max_signature_s(Configuration.t()) :: atom()
  def max_signature_s(config), do: config.max_signature_s

  @spec fail_contract_creation_lack_of_gas?(Configuration.t()) :: boolean()
  def fail_contract_creation_lack_of_gas?(config), do: config.fail_contract_creation

  @spec extcodesize_cost(Configuration.t()) :: integer()
  def extcodesize_cost(config), do: config.extcodesize_cost

  @spec extcodecopy_cost(Configuration.t()) :: integer()
  def extcodecopy_cost(config), do: config.extcodecopy_cost

  @spec balance_cost(Configuration.t()) :: integer()
  def balance_cost(config), do: config.balance_cost

  @spec sload_cost(Configuration.t()) :: integer()
  def sload_cost(config), do: config.sload_cost

  @spec call_cost(Configuration.t()) :: integer()
  def call_cost(config), do: config.call_cost

  @spec selfdestruct_cost(Configuration.t(), keyword()) :: integer()
  def selfdestruct_cost(config, _params), do: config.selfdestruct_cost

  @spec fail_nested_operation_lack_of_gas?(Configuration.t()) :: boolean()
  def fail_nested_operation_lack_of_gas?(config), do: config.fail_nested_operation

  @spec exp_byte_cost(Configuration.t()) :: integer()
  def exp_byte_cost(config), do: config.exp_byte_cost

  @spec limit_contract_code_size?(Configuration.t(), integer()) :: boolean()
  def limit_contract_code_size?(config, _), do: config.limit_contract_code_size

  @spec increment_nonce_on_create?(Configuration.t()) :: boolean()
  def increment_nonce_on_create?(config), do: config.increment_nonce_on_create

  @spec empty_account_value_transfer?(Configuration.t()) :: boolean()
  def empty_account_value_transfer?(config), do: config.empty_account_value_transfer

  @spec clean_touched_accounts?(Configuration.t()) :: boolean()
  def clean_touched_accounts?(config), do: config.clean_touched_accounts

  @spec has_revert?(Configuration.t()) :: boolean()
  def has_revert?(config), do: config.has_revert

  @spec has_static_call?(Configuration.t()) :: boolean()
  def has_static_call?(config), do: config.has_static_call

  @spec support_variable_length_return_value?(Configuration.t()) :: boolean()
  def support_variable_length_return_value?(config),
    do: config.support_variable_length_return_value

  @spec has_mod_exp_builtin?(Configuration.t()) :: boolean()
  def has_mod_exp_builtin?(config), do: config.has_mod_exp_builtin

  @spec has_ec_add_builtin?(Configuration.t()) :: boolean()
  def has_ec_add_builtin?(config), do: config.has_ec_add_builtin

  @spec has_ec_mult_builtin?(Configuration.t()) :: boolean()
  def has_ec_mult_builtin?(config), do: config.has_ec_mult_builtin

  @spec has_ec_pairing_builtin?(Configuration.t()) :: boolean()
  def has_ec_pairing_builtin?(config), do: config.has_ec_pairing_builtin

  @spec has_shift_operations?(Configuration.t()) :: boolean()
  def has_shift_operations?(config), do: config.has_shift_operations

  @spec has_extcodehash?(Configuration.t()) :: boolean()
  def has_extcodehash?(config), do: config.has_extcodehash

  @spec has_create2?(Configuration.t()) :: boolean()
  def has_create2?(config), do: config.has_create2
end
