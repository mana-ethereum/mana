defmodule Blockchain.Transaction.AccountCleaner do
  alias Blockchain.Account
  alias Blockchain.Account.Repo

  def clean_touched_accounts(account_repo, accounts, config) do
    if config.clean_touched_accounts do
      Enum.reduce(accounts, account_repo, fn address, new_account_repo ->
        {updated_repo, account} = Repo.account(new_account_repo, address)

        if account && Account.empty?(account) do
          Repo.del_account(updated_repo, address)
        else
          updated_repo
        end
      end)
    else
      account_repo
    end
  end
end
