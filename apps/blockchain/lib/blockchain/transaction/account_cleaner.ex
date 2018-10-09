defmodule Blockchain.Transaction.AccountCleaner do
  alias Blockchain.Account
  alias Blockchain.Account.Repo
  alias EVM.Configuration

  def clean_touched_accounts(account_repo, accounts, config) do
    if Configuration.for(config).clean_touched_accounts?(config) do
      Enum.reduce(accounts, account_repo, fn address, new_account_repo ->
        account = Repo.account(new_account_repo, address)

        if account && Account.empty?(account) do
          Repo.del_account(new_account_repo, address)
        else
          new_account_repo
        end
      end)
    else
      account_repo
    end
  end
end
