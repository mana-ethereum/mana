defmodule EVM.Configuration do
  @moduledoc """
  Behaviour for hardfork configurations.
  """

  @type t :: struct()

  # EIP2
  @callback contract_creation_cost(t) :: integer()

  # EIP2
  @callback fail_contract_creation_lack_of_gas?(t) :: boolean()

  # EIP2
  @callback max_signature_s(t) :: atom()

  # EIP7
  @callback has_delegate_call?(t) :: boolean()

  # EIP150
  @callback extcodesize_cost(t) :: integer()

  # EIP150
  @callback extcodecopy_cost(t) :: integer()

  # EIP150
  @callback balance_cost(t) :: integer()

  # EIP150
  @callback sload_cost(t) :: integer()

  # EIP150
  @callback call_cost(t) :: integer()

  # EIP150
  @callback selfdestruct_cost(t, keyword()) :: integer()

  # EIP150
  @callback fail_nested_operation_lack_of_gas?(t) :: boolean()

  # EIP160
  @callback exp_byte_cost(t) :: integer()

  # EIP161-a
  @callback increment_nonce_on_create?(t) :: boolean()

  # EIP161-b
  @callback empty_account_value_transfer?(t) :: boolean()

  # EIP161-cd
  @callback clean_touched_accounts?(t) :: boolean()

  # EIP170
  @callback limit_contract_code_size?(t, integer) :: boolean()

  # EIP140
  @callback has_revert?(t) :: boolean()

  # EIP211
  @callback support_variable_length_return_value?(t) :: boolean()

  # EIP214
  @callback has_static_call?(t) :: boolean()

  # EIP196
  @callback has_ec_add_builtin?(t) :: boolean()

  # EIP196
  @callback has_ec_mult_builtin?(t) :: boolean()

  # EIP197
  @callback has_ec_pairing_builtin?(t) :: boolean()

  # EIP198
  @callback has_mod_exp_builtin?(t) :: boolean()

  # EIP658
  @callback status_in_receipt?(t) :: boolean()

  # EIP145
  @callback has_shift_operations?(t) :: boolean()

  # EIP1052
  @callback has_extcodehash?(t) :: boolean()

  # EIP1014
  @callback has_create2?(t) :: boolean()

  # EIP1283
  @callback eip1283_sstore_gas_cost_changed?(t) :: boolean()

  @spec for(t) :: module()
  def for(config) do
    config.__struct__
  end

  @spec hardfork_config(String.t()) :: t()
  def hardfork_config(hardfork) do
    case hardfork do
      "Frontier" ->
        EVM.Configuration.Frontier.new()

      "Homestead" ->
        EVM.Configuration.Homestead.new()

      "HomesteadToDaoAt5" ->
        EVM.Configuration.Homestead.new()

      "TangerineWhistle" ->
        EVM.Configuration.TangerineWhistle.new()

      "SpuriousDragon" ->
        EVM.Configuration.SpuriousDragon.new()

      "Byzantium" ->
        EVM.Configuration.Byzantium.new()

      "Constantinople" ->
        EVM.Configuration.Constantinople.new()

      _ ->
        nil
    end
  end
end
