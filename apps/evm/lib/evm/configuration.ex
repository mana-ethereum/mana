defprotocol EVM.Configuration do
  @moduledoc """
  Protocol for defining hardfork configurations.
  """

  @type t :: module()

  # EIP2
  @spec contract_creation_cost(t) :: integer()
  def contract_creation_cost(t)

  # EIP2
  @spec fail_contract_creation_lack_of_gas?(t) :: boolean()
  def fail_contract_creation_lack_of_gas?(t)

  # EIP2
  @spec max_signature_s(t) :: atom()
  def max_signature_s(t)

  # EIP7
  @spec has_delegate_call?(t) :: boolean()
  def has_delegate_call?(t)

  # EIP150
  @spec extcodesize_cost(t) :: integer()
  def extcodesize_cost(t)

  # EIP150
  @spec extcodecopy_cost(t) :: integer()
  def extcodecopy_cost(t)

  # EIP150
  @spec balance_cost(t) :: integer()
  def balance_cost(t)

  # EIP150
  @spec sload_cost(t) :: integer()
  def sload_cost(t)

  # EIP150
  @spec call_cost(t) :: integer()
  def call_cost(t)

  # EIP150
  @spec selfdestruct_cost(t, keyword()) :: integer()
  def selfdestruct_cost(t, params \\ [])

  # EIP150
  @spec fail_nested_operation_lack_of_gas?(t) :: boolean()
  def fail_nested_operation_lack_of_gas?(t)

  # EIP160
  @spec exp_byte_cost(t) :: integer()
  def exp_byte_cost(t)

  # EIP161-a
  @spec increment_nonce_on_create?(t) :: boolean()
  def increment_nonce_on_create?(t)

  # EIP161-b
  @spec empty_account_value_transfer?(t) :: boolean()
  def empty_account_value_transfer?(t)

  # EIP161-cd
  @spec clean_touched_accounts?(t) :: boolean()
  def clean_touched_accounts?(t)

  # EIP170
  @spec limit_contract_code_size?(t, integer) :: boolean()
  def limit_contract_code_size?(t, size \\ 0)

  # EIP140
  @spec has_revert?(t) :: boolean()
  def has_revert?(t)

  # EIP211
  @spec support_variable_length_return_value?(t) :: boolean()
  def support_variable_length_return_value?(t)

  # EIP214
  @spec has_static_call?(t) :: boolean()
  def has_static_call?(t)

  # EIP196
  @spec has_ec_add_builtin?(t) :: boolean()
  def has_ec_add_builtin?(t)

  # EIP196
  @spec has_ec_mult_builtin?(t) :: boolean()
  def has_ec_mult_builtin?(t)

  # EIP197
  @spec has_ec_pairing_builtin?(t) :: boolean()
  def has_ec_pairing_builtin?(t)

  # EIP198
  @spec has_mod_exp_builtin?(t) :: boolean()
  def has_mod_exp_builtin?(t)

  # EIP145
  @spec has_shift_operations?(t) :: boolean()
  def has_shift_operations?(t)

  # EIP1052
  @spec has_extcodehash?(t) :: boolean()
  def has_extcodehash?(t)

  # EIP1014
  @spec has_create2?(t) :: boolean()
  def has_create2?(t)
end
