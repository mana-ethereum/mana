defmodule EVM.Interface.Mock.MockAccountInterface do
  @moduledoc """
  Simple implementation of a account interface.
  """

  defstruct [
    account_map: nil,
  ]

  def new(opts) do
    struct(__MODULE__, opts)
  end

end

defimpl EVM.Interface.AccountInterface, for: EVM.Interface.Mock.MockAccountInterface do

  @spec get_account_balance(EVM.Interface.AccountInterface.t, EVM.state, EVM.address) :: nil | EVM.Wei.t
  def get_account_balance(mock_account_interface, _state, address) do
    account = get_account(mock_account_interface, address)

    if account do
      account.balance
    end
  end

  @spec get_account_code(EVM.Interface.AccountInterface.t, EVM.state, EVM.address) :: nil | integer()
  def get_account_code(mock_account_interface, _state, address) do
    account = get_account(mock_account_interface, address)

    if account do
      account.code
    end
  end

  @spec increment_account_nonce(EVM.Interface.AccountInterface.t, EVM.state, EVM.address) :: { EVM.state, integer() }
  def increment_account_nonce(mock_account_interface, state, address) do
    {state, Map.get(mock_account_interface.account_map, address).nonce + 1}
  end

  defp get_account(mock_account_interface, address), do:
    Map.get(mock_account_interface.account_map, address)

end
