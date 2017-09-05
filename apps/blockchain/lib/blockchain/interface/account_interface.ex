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

end