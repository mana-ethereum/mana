defmodule Blockchain.Interface.AccountInterfaceTest do
  use ExUnit.Case, async: true
  doctest Blockchain.Interface.AccountInterface
  doctest EVM.Interface.AccountInterface.Blockchain.Interface.AccountInterface

  alias Blockchain.Account
  alias Blockchain.Interface.AccountInterface
  alias Blockchain.Interface.AccountInterface.Cache

  setup do
    state =
      :account_interface_test
      |> MerklePatriciaTree.Test.random_ets_db()
      |> MerklePatriciaTree.Trie.new()

    {:ok, %{state: state}}
  end

  describe "increment_account_nonce/2" do
    test "increments nonce of the account in the casge", %{state: state} do
      address = <<1>>
      state_with_account = Account.reset_account(state, address)

      result =
        state_with_account
        |> AccountInterface.new()
        |> AccountInterface.increment_account_nonce(address)
        |> AccountInterface.increment_account_nonce(address)
        |> AccountInterface.account(address)

      assert result.nonce == 2
    end
  end

  describe "account/2" do
    test "fetches account from cache", %{state: state} do
      account = %Account{
        nonce: 5,
        balance: 10,
        storage_root: <<0x00, 0x01>>,
        code_hash: <<0x01, 0x02>>
      }

      address = <<1>>
      code = <<5>>
      cache = %Cache{accounts_cache: %{address => {account, code}}}

      account_interface =
        state
        |> Account.reset_account(address)
        |> AccountInterface.new(cache)

      assert AccountInterface.account(account_interface, address) == {account, code}
    end

    test "fetches account from storage", %{state: state} do
      address = <<1>>

      account_interface =
        state
        |> Account.reset_account(address)
        |> AccountInterface.new()

      result = AccountInterface.account(account_interface, address)

      assert result == %Blockchain.Account{
               balance: 0,
               code_hash:
                 <<197, 210, 70, 1, 134, 247, 35, 60, 146, 126, 125, 178, 220, 199, 3, 192, 229,
                   0, 182, 83, 202, 130, 39, 59, 123, 250, 216, 4, 93, 133, 164, 112>>,
               nonce: 0,
               storage_root:
                 <<86, 232, 31, 23, 27, 204, 85, 166, 255, 131, 69, 230, 146, 192, 248, 110, 91,
                   72, 224, 27, 153, 108, 173, 192, 1, 98, 47, 181, 227, 99, 180, 33>>
             }
    end
  end
end
