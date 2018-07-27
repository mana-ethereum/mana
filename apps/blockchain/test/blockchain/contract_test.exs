defmodule Blockchain.ContractTest do
  use ExUnit.Case, async: true
  doctest Blockchain.Contract

  alias Blockchain.{Account, Contract}
  alias MerklePatriciaTree.Trie

  setup do
    db = MerklePatriciaTree.Test.random_ets_db(:contract_test)
    {:ok, %{db: db}}
  end

  describe "create_blank/4" do
    test "creates valid blank contract", %{db: db} do
      sender_address = <<0x01::160>>
      contract_address = <<0x02::160>>
      sender_account = %Account{balance: 10}
      endowment = 6

      accounts =
        db
        |> Trie.new()
        |> Account.put_account(sender_address, sender_account)
        |> Contract.create_blank(contract_address, sender_address, endowment)
        |> Account.get_accounts([sender_address, contract_address])

      expected_accounts = [
        %Account{balance: sender_account.balance - endowment},
        %Account{balance: endowment, nonce: 0}
      ]

      assert accounts == expected_accounts
    end
  end
end
