defmodule EVM.Configuration do
  @moduledoc """
  Behaviour for hardfork configurations.
  """

  defmacro __using__(opts) do
    fallback_config = Keyword.fetch!(opts, :fallback_config)
    overrides = Keyword.fetch!(opts, :overrides)

    quote do
      @behaviour EVM.Configuration

      defstruct unquote(fallback_config).new()
                |> Map.from_struct()
                |> Map.merge(unquote(overrides))
                |> Enum.into([])

      @impl true
      def new, do: %__MODULE__{}
    end
  end

  @type t :: %{
          :contract_creation_cost => non_neg_integer(),
          :has_delegate_call => boolean(),
          :should_fail_contract_creation_lack_of_gas => boolean(),
          :max_signature_s => :secp256k1n | :secp256k1n_2,
          :extcodesize_cost => non_neg_integer(),
          :extcodecopy_cost => non_neg_integer(),
          :balance_cost => non_neg_integer(),
          :sload_cost => non_neg_integer(),
          :call_cost => non_neg_integer(),
          :selfdestruct_cost => non_neg_integer(),
          :should_fail_nested_operation_lack_of_gas => boolean(),
          :exp_byte_cost => non_neg_integer(),
          :limit_contract_code_size => boolean(),
          :increment_nonce_on_create => boolean(),
          :empty_account_value_transfer => boolean(),
          :clean_touched_accounts => boolean(),
          :has_revert => boolean(),
          :has_static_call => boolean(),
          :support_variable_length_return_value => boolean(),
          :has_mod_exp_builtin => boolean(),
          :status_in_receipt => boolean(),
          :has_ec_add_builtin => boolean(),
          :has_ec_mult_builtin => boolean(),
          :has_ec_pairing_builtin => boolean(),
          :has_shift_operations => boolean(),
          :has_extcodehash => boolean(),
          :has_create2 => boolean(),
          :eip1283_sstore_gas_cost_changed => boolean(),
          optional(atom) => any()
        }

  @callback new() :: t()

  # EIP150
  @callback selfdestruct_cost(t, keyword()) :: integer()

  # EIP170
  @callback limit_contract_code_size?(t, integer) :: boolean()

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
