defprotocol EVM.Interface.AccountInterface do
  @moduledoc """
  Interface for interacting with accounts.
  """

  @type t :: module()

  @spec get_account_balance(t, EVM.state, EVM.address) :: nil | EVM.Wei.t
  def get_account_balance(t, state, address)

  @spec increment_account_nonce(t, EVM.state, EVM.address) :: { EVM.state, integer() }
  def increment_account_nonce(t, state, address)

end