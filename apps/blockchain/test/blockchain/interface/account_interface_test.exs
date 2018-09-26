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

  describe "transfer_wei!/4" do
    test "transfers wei from one account to another reading accounts from the storage", %{
      state: state
    } do
      from_account_address = <<1>>
      from_account_balance = 6
      transfer_wei = 2

      from_account = %Blockchain.Account{
        nonce: 5,
        balance: from_account_balance,
        storage_root: <<0x01>>,
        code_hash: <<0x02>>
      }

      to_account_address = <<2>>

      updated_account_interface =
        state
        |> Account.reset_account(to_account_address)
        |> Account.put_account(from_account_address, from_account)
        |> AccountInterface.new()
        |> AccountInterface.transfer_wei!(from_account_address, to_account_address, transfer_wei)

      new_from_account = AccountInterface.account(updated_account_interface, from_account_address)

      assert new_from_account.balance == from_account_balance - transfer_wei

      new_to_account = AccountInterface.account(updated_account_interface, to_account_address)

      assert new_to_account.balance == transfer_wei
    end
  end

  describe "put_code/3" do
    test "sets code to the account", %{state: state} do
      code = <<1, 2, 3>>
      address = <<2>>

      {account, ^code} =
        state
        |> Account.reset_account(address)
        |> AccountInterface.new()
        |> AccountInterface.put_code(address, code)
        |> AccountInterface.account_with_code(address)

      assert account.code_hash ==
               <<241, 136, 94, 218, 84, 183, 160, 83, 49, 140, 212, 30, 32, 147, 34, 13, 171, 21,
                 214, 83, 129, 177, 21, 122, 54, 51, 168, 59, 253, 92, 146, 57>>
    end
  end

  describe "machine_code/2" do
    test "returns machine code from cache", %{state: state} do
      account = %Account{
        nonce: 5,
        balance: 10,
        storage_root: <<0x00, 0x01>>,
        code_hash: <<0x01, 0x02>>
      }

      address = <<1>>
      code = <<5>>
      cache = %Cache{accounts_cache: %{address => {account, code}}}

      {:ok, found_code} =
        state
        |> AccountInterface.new(cache)
        |> AccountInterface.machine_code(address)

      assert code == found_code
    end

    test "returns machine code from storage", %{state: state} do
      address = <<1>>
      code = <<5>>

      {:ok, found_code} =
        state
        |> Account.reset_account(address)
        |> Account.put_code(address, code)
        |> AccountInterface.new()
        |> AccountInterface.machine_code(address)

      assert found_code == code
    end
  end

  describe "clear_balance/2" do
    test "clears account's balance", %{state: state} do
      address = <<1>>

      account = %Account{
        nonce: 5,
        balance: 10,
        storage_root: <<0x00, 0x01>>,
        code_hash: <<0x01, 0x02>>
      }

      found_account =
        state
        |> Account.put_account(address, account)
        |> AccountInterface.new()
        |> AccountInterface.clear_balance(address)
        |> AccountInterface.account(address)

      assert found_account.balance == 0
    end
  end

  describe "reset_account/2" do
    test "resets account", %{state: state} do
      address = <<1>>

      account = %Account{
        nonce: 5,
        balance: 10,
        storage_root: <<0x00, 0x01>>,
        code_hash: <<0x01, 0x02>>
      }

      found_account =
        state
        |> Account.put_account(address, account)
        |> AccountInterface.new()
        |> AccountInterface.reset_account(address)
        |> AccountInterface.account(address)

      assert found_account == %Account{}
    end
  end

  describe "add_wei/2" do
    test "adds wei to account's balance", %{state: state} do
      address = <<1>>

      account = %Account{
        nonce: 5,
        balance: 10,
        storage_root: <<0x00, 0x01>>,
        code_hash: <<0x01, 0x02>>
      }

      found_account =
        state
        |> Account.put_account(address, account)
        |> AccountInterface.new()
        |> AccountInterface.add_wei(address, 100)
        |> AccountInterface.account(address)

      assert found_account.balance == 110
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

      assert AccountInterface.account_with_code(account_interface, address) == {account, code}
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
               code_hash: Account.empty_keccak(),
               nonce: 0,
               storage_root: Account.empty_trie()
             }
    end
  end
end
