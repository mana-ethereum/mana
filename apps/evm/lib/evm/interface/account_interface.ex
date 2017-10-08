defprotocol EVM.Interface.AccountInterface do
  @moduledoc """
  Interface for interacting with accounts.
  """

  @type t :: module()

  @spec get_account_balance(t, EVM.address) :: nil | EVM.Wei.t
  def get_account_balance(t, address)

  @spec get_account_code(t, EVM.address) :: nil | binary()
  def get_account_code(t, address)

  @spec increment_account_nonce(t, EVM.address) :: t
  def increment_account_nonce(t, address)

  @spec get_storage(t, EVM.address, EVM.val) :: EVM.val
  def get_storage(t, address, key)

  @spec suicide_account(t, EVM.address) :: t
  def suicide_account(mock_account_interface, address)

  @spec put_storage(t, EVM.address, EVM.val, EVM.val) :: EVM.val
  def put_storage(t, address, key, value)

  @spec dump_storage(t) :: %{EVM.address => EVM.val}
  def dump_storage(t)

end
