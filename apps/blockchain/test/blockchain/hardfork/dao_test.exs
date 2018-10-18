defmodule Blockchain.Hardfork.DaoTest do
  use ExUnit.Case, async: true

  alias Blockchain.{Account, Chain}
  alias Blockchain.Hardfork.Dao

  describe "execute" do
    test "transfers all DAO account funds into the refund contract" do
      chain = Chain.load_chain(:foundation)
      dao_accounts = dao_hardfork_accounts(chain)
      beneficiary_account = dao_beneficiary(chain)

      repo =
        build_repo()
        |> put_balance_in_accounts(dao_accounts, balance: 10)
        |> Account.Repo.put_account(beneficiary_account, %Account{balance: 0})
        |> Account.Repo.commit()

      new_repo = Dao.execute(repo, chain)

      Enum.each(dao_accounts, fn account ->
        balance = Account.Repo.get_account_balance(new_repo, account)
        assert balance == 0
      end)

      beneficiary_balance = Account.Repo.get_account_balance(new_repo, beneficiary_account)
      assert beneficiary_balance == Enum.count(dao_accounts) * 10
    end
  end

  defp build_repo do
    MerklePatriciaTree.Test.random_ets_db()
    |> MerklePatriciaTree.Trie.new()
    |> Account.Repo.new()
  end

  defp dao_beneficiary(chain) do
    chain.engine["Ethash"][:dao_hardfork_beneficiary]
  end

  defp dao_hardfork_accounts(chain) do
    chain.engine["Ethash"][:dao_hardfork_accounts]
  end

  defp put_balance_in_accounts(repo, account_addresses, balance: balance) do
    Enum.reduce(account_addresses, repo, fn address, acc_repo ->
      account = %Account{balance: balance}
      Account.Repo.put_account(acc_repo, address, account)
    end)
  end
end
