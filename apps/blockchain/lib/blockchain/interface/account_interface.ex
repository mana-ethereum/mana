defmodule Blockchain.Interface.AccountInterface do
  @moduledoc """
  Defines an interface for methods to interact with accounts.
  """

  @type t :: %__MODULE__{}

  defstruct []

  @doc """
  Returns a new account interface.

  ## Examples

      iex> Blockchain.Interface.AccountInterface.new()
      %Blockchain.Interface.AccountInterface{}
  """
  def new() do
    %__MODULE__{}
  end
end

defimpl EVM.Interface.AccountInterface, for: Blockchain.Interface.AccountInterface do

  # TODO: Add test case
  @spec get_account_balance(EVM.Interface.AccountInterface.t, EVM.state, EVM.address) :: nil | EVM.Wei.t
  def get_account_balance(_account_interface, state, address) do
    case Blockchain.Account.get_account(state, address) do
      nil -> nil
      account -> account.balance
    end
  end

  # TODO: Add test case
  @spec get_account_code(EVM.Interface.AccountInterface.t, EVM.state, EVM.address) :: nil | binary()
  def get_account_code(_account_interface, state, address) do
    case Blockchain.Account.get_machine_code(state, address) do
      {:ok, machine_code} -> machine_code
      :not_found -> nil
    end
  end

  # TODO: Add test case
  @spec increment_account_nonce(EVM.Interface.AccountInterface.t, EVM.state, EVM.address) :: { EVM.state, integer() }
  def increment_account_nonce(_account_interface, state, address) do
    { state, before_acct, _after_acct } = Blockchain.Account.increment_nonce(state, address, true)

    { state, before_acct.nonce }
  end

end