defmodule Blockchain.Transaction.AccountCleaner do
  alias Blockchain.Account
  alias Blockchain.Interface.AccountInterface
  alias EVM.Configuration

  def clean_touched_accounts(account_interface, accounts, config) do
    if Configuration.for(config).clean_touched_accounts?(config) do
      Enum.reduce(accounts, account_interface, fn address, new_account_interface ->
        account = AccountInterface.account(new_account_interface, address)

        if account && Account.empty?(account) do
          AccountInterface.del_account(new_account_interface, address)
        else
          new_account_interface
        end
      end)
    else
      account_interface
    end
  end
end
