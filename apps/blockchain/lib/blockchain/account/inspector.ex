defmodule Blockchain.Account.Inspector do
  @moduledoc """
  Module to inspect account information
  """

  alias Blockchain.Account

  @doc """
  Prints a visual representation of several accounts
  """
  def inspect_accounts(state, account_addresses) do
    Enum.map(account_addresses, &inspect_account(state, &1))
  end

  @doc """
  Prints a visual representation of an account
  """
  def inspect_account(state, account_address) do
    address_key = Base.decode16!(account_address, case: :mixed)
    account = Account.get_account(state, address_key)

    if is_nil(account) do
      IO.puts("#{account_address} does not exist")
    else
      """
      #{account_address}
        Balance: #{account.balance}
        Nonce: #{account.nonce}
        Storage Root:
          #{encode(account.storage_root)}
        Code Hash:
          #{encode(account.code_hash)}
      """
      |> IO.puts()
    end
  end

  defp encode(binary) do
    Base.encode16(binary, case: :lower)
  end
end
