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
            start_nonce: 0,
            empty_account_value_transfer: false,
            clean_touched_accounts: false

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

  @spec start_nonce(Configuration.t()) :: integer()
  def start_nonce(config), do: config.start_nonce

  @spec empty_account_value_transfer?(Configuration.t()) :: boolean()
  def empty_account_value_transfer?(config), do: config.empty_account_value_transfer

  @spec clean_touched_accounts?(Configuration.t()) :: boolean()
  def clean_touched_accounts?(config), do: config.clean_touched_accounts
end
