defprotocol EVM.Interface.AccountInterface do
  @moduledoc """
  Interface for interacting with accounts.
  """

  @type t :: module()

  @spec account_exists?(t, EVM.address) :: boolean()
  def account_exists?(t, address)

  @spec get_account_balance(t, EVM.address) :: nil | EVM.Wei.t
  def get_account_balance(t, address)

  @spec get_account_code(t, EVM.address) :: nil | binary()
  def get_account_code(t, address)

  @spec get_account_nonce(EVM.Interface.AccountInterface.t, EVM.address) :: integer()
  def get_account_nonce(mock_account_interface, address)

  @spec increment_account_nonce(t, EVM.address) :: t
  def increment_account_nonce(t, address)

  @spec get_storage(t, EVM.address, integer()) :: {:ok, integer()} | :account_not_found | :key_not_found
  def get_storage(t, address, key)

  @spec put_storage(t, EVM.address, integer(), integer()) :: t
  def put_storage(t, address, key, value)

  @spec suicide_account(t, EVM.address) :: t
  def suicide_account(t, address)

  @spec dump_storage(t) :: %{ EVM.address => EVM.val }
  def dump_storage(t)

  @spec message_call(t, EVM.address, EVM.address, EVM.address, EVM.address, EVM.Gas.t, EVM.Gas.gas_price, EVM.Wei.t, EVM.Wei.t, binary(), integer(), Header.t) :: { t, EVM.Gas.t, EVM.SubState.t, EVM.VM.output }
  def message_call(t, sender, originator, recipient, contract, available_gas, gas_price, value, apparent_value, data, stack_depth, block_header)

  @spec create_contract(t, EVM.address, EVM.address, EVM.Gas.t, EVM.Gas.gas_price, EVM.Wei.t, EVM.MachineCode.t, integer(), Header.t) :: { t, EVM.Gas.t, EVM.SubState.t }
  def create_contract(t, sender, originator, available_gas, gas_price, endowment, init_code, stack_depth, block_header)

  @spec new_contract_address(t, EVM.address, integer()) :: EVM.address
  def new_contract_address(t, address, nonce)

end
