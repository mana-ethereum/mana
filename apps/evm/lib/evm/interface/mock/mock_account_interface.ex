defmodule EVM.Interface.Mock.MockAccountInterface do
  @moduledoc """
  Simple implementation of a account interface.
  """

  defstruct [
    balance: nil,
    nonce: nil
  ]

  def new(opts) do
    struct(__MODULE__, opts)
  end

end

defimpl EVM.Interface.AccountInterface, for: EVM.Interface.Mock.MockAccountInterface do

  @spec get_account_balance(EVM.Interface.AccountInterface.t, EVM.state, EVM.address) :: nil | EVM.Wei.t
  def get_account_balance(mock_account_interface, _state, _address) do
    mock_account_interface.balance
  end

  @spec increment_account_nonce(EVM.Interface.AccountInterface.t, EVM.state, EVM.address) :: { EVM.state, integer() }
  def increment_account_nonce(mock_account_interface, state, _address) do
    { state, mock_account_interface.nonce + 1 }
  end

end