defprotocol EVM.Interface.AccountInterface do
  @moduledoc """
  Interface for interacting with accounts.
  """

  @type t :: module()

  @spec get_account_balance(t, EVM.state, EVM.address) :: nil | EVM.Wei.t
  def get_account_balance(t, state, address)

end