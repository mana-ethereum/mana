defmodule Blockchain.Account.InspectorTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Blockchain.Account.{Inspector, Repo}

  describe "inspect_account/1" do
    test "prints a visual representation of an account" do
      account = %Blockchain.Account{balance: 10, nonce: 3}
      account_address = <<1::160>>
      hex_account_address = Base.encode16(account_address, case: :lower)

      state =
        :random_db
        |> MerklePatriciaTree.Test.random_ets_db()
        |> MerklePatriciaTree.Trie.new()

      repo =
        state
        |> Repo.new()
        |> Repo.put_account(account_address, account)
        |> Repo.commit()

      io_result =
        capture_io(fn ->
          Inspector.inspect_account(repo.state, hex_account_address)
        end)

      assert io_result =~ hex_account_address
      assert io_result =~ "Balance: #{account.balance}"
      assert io_result =~ "Nonce: #{account.nonce}"
    end
  end
end
