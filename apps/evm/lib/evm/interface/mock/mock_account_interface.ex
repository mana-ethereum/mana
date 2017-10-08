defmodule EVM.Interface.Mock.MockAccountInterface do
  @moduledoc """
  Simple implementation of a account interface.
  """

  defstruct [
    account_map: %{},
  ]

  def new(opts \\ %{}) do
    struct(__MODULE__, %{account_map: opts})
  end

end

defimpl EVM.Interface.AccountInterface, for: EVM.Interface.Mock.MockAccountInterface do

  @spec get_account_balance(EVM.Interface.AccountInterface.t, EVM.address) :: nil | EVM.Wei.t
  def get_account_balance(mock_account_interface, address) do
    account = get_account(mock_account_interface, address)

    if account do
      account.balance
    end
  end

  @spec get_account_code(EVM.Interface.AccountInterface.t, EVM.address) :: nil | binary()
  def get_account_code(mock_account_interface, address) do
    account = get_account(mock_account_interface, address)

    if account do
      account.code
    end
  end

  @spec get_storage(EVM.Interface.AccountInterface.t, EVM.state, EVM.address) :: nil | binary()
  def get_storage(mock_account_interface, address, key) do
    get_in(mock_account_interface.account_map, [address, :storage, key]) || 0
  end

  @spec put_storage(EVM.Interface.AccountInterface.t, EVM.address, EVM.val, EVM.val) :: nil | binary()
  def put_storage(mock_account_interface, address, key, value) do
    account = get_account(mock_account_interface, address)
    account = if account do
      update_storage(account, key, value)
    else
      new_account(%{storage: %{key => value}})
    end

    put_account(mock_account_interface, address, account)
  end

  defp put_account(mock_account_interface, address, account) do
    struct(
      EVM.Interface.Mock.MockAccountInterface,
      %{account_map: Map.put(mock_account_interface.account_map, address, account)}
    )
  end

  def suicide_account(mock_account_interface, address) do
    account_map = mock_account_interface.account_map
      |> Map.delete(address)

    struct(
      EVM.Interface.Mock.MockAccountInterface,
      %{account_map: account_map}
    )
  end

  defp update_storage(account, key, value) do
    put_in(account, [:storage, key], value)
  end

  defp new_account(opts) do
    Map.merge(%{
      storage: %{},
      nonce: 0,
      balance: 0,
    }, opts)
  end

  @spec increment_account_nonce(EVM.Interface.AccountInterface.t, EVM.address) :: integer()
  def increment_account_nonce(mock_account_interface, address) do
    Map.get(mock_account_interface.account_map, address).nonce + 1
  end

  def dump_storage(mock_account_interface) do
    for {address, account} <- mock_account_interface.account_map, into: %{} do
      storage = account[:storage]
        |> Enum.reject(fn({_key, value}) -> value == 0 end)
        |> Enum.into(%{})
      {address, storage}
    end
  end

  defp get_account(mock_account_interface, address), do:
    Map.get(mock_account_interface.account_map, address)

end
