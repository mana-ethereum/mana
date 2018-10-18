defmodule Blockchain.Hardfork.Dao do
  alias Blockchain.Account

  @spec execute(Account.Repo.t(), Blockchain.Chain.t()) :: Account.Repo.t()
  def execute(repo, chain) do
    dao_beneficiary = dao_beneficiary(chain)

    chain
    |> dao_hardfork_accounts()
    |> transfer_all_balances(to: dao_beneficiary, repo: repo)
    |> Account.Repo.commit()
  end

  defp transfer_all_balances(accounts, to: to, repo: repo) do
    Enum.reduce(accounts, repo, fn account, current_repo ->
      balance = Account.Repo.get_account_balance(repo, account)
      Account.Repo.transfer(current_repo, account, to, balance)
    end)
  end

  defp dao_hardfork_accounts(chain) do
    chain.engine["Ethash"][:dao_hardfork_accounts]
  end

  defp dao_beneficiary(chain) do
    chain.engine["Ethash"][:dao_hardfork_beneficiary]
  end
end
