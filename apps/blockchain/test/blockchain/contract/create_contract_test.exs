defmodule Blockchain.Contract.CreateContractTest do
  use ExUnit.Case
  doctest Blockchain.Contract.CreateContract

  alias Blockchain.{Account, Contract}
  alias EVM.{SubState, MachineCode}
  alias MerklePatriciaTree.{Trie, DB}
  alias Blockchain.Interface.AccountInterface

  setup do
    db = MerklePatriciaTree.Test.random_ets_db(:contract_test)
    {:ok, %{db: db}}
  end

  describe "execute/1" do
    test "creates a new contract", %{db: db} do
      account = %Account{balance: 11, nonce: 5}

      state =
        db
        |> Trie.new()
        |> Account.put_account(<<0x10::160>>, account)

      params = %Contract.CreateContract{
        account_interface: AccountInterface.new(state),
        sender: <<0x10::160>>,
        originator: <<0x10::160>>,
        available_gas: 100_000_000,
        gas_price: 1,
        endowment: 5,
        init_code: build_sample_code(),
        stack_depth: 5,
        block_header: %Block.Header{nonce: 1}
      }

      {_, {state, gas, sub_state}} = Contract.create(params)

      expected_root_hash =
        <<9, 235, 32, 146, 153, 242, 209, 192, 224, 61, 214, 174, 48, 24, 148, 28, 51, 254, 7, 82,
          58, 82, 220, 157, 29, 159, 203, 51, 52, 240, 37, 122>>

      assert state == %Trie{db: {DB.ETS, :contract_test}, root_hash: expected_root_hash}
      assert gas == 99_993_576
      assert SubState.empty?(sub_state)

      addresses = [<<0x10::160>>, Account.Address.new(<<0x10::160>>, 5)]
      actual_accounts = Account.get_accounts(state, addresses)

      expected_accounts = [
        %Account{balance: 6, nonce: 5},
        %Account{
          balance: 5,
          nonce: 0,
          code_hash:
            <<243, 247, 169, 254, 54, 79, 170, 185, 59, 33, 109, 165, 10, 50, 20, 21, 79, 34, 160,
              162, 180, 21, 178, 58, 132, 200, 22, 158, 139, 99, 110, 227>>
        }
      ]

      assert actual_accounts == expected_accounts

      contract_address = Account.Address.new(<<0x10::160>>, 5)
      assert Account.get_machine_code(state, contract_address) == {:ok, <<0x08::256>>}
      assert state |> Trie.Inspector.all_keys() |> Enum.count() == 2
    end

    test "does not create contract if address already exists with nonce", %{db: db} do
      account = %Account{balance: 11, nonce: 5}
      account_address = <<0x10::160>>
      collision_account = %Account{nonce: 1}
      collision_account_address = Account.Address.new(account_address, account.nonce)

      state =
        db
        |> Trie.new()
        |> Account.put_account(account_address, account)
        |> Account.put_account(collision_account_address, collision_account)

      params = %Contract.CreateContract{
        account_interface: AccountInterface.new(state),
        sender: account_address,
        originator: account_address,
        available_gas: 100_000_000,
        gas_price: 1,
        endowment: 5,
        init_code: build_sample_code(),
        stack_depth: 5,
        block_header: %Block.Header{nonce: 1}
      }

      assert {:error, {^state, 0, sub_state}} = Contract.create(params)
      assert SubState.empty?(sub_state)
    end

    test "does not create contract if address has code", %{db: db} do
      account = %Account{balance: 11, nonce: 5}
      account_address = <<0x10::160>>
      collision_account = %Account{code_hash: build_sample_code(), nonce: 0}
      collision_account_address = Account.Address.new(account_address, account.nonce)

      state =
        db
        |> Trie.new()
        |> Account.put_account(account_address, account)
        |> Account.put_account(collision_account_address, collision_account)

      params = %Contract.CreateContract{
        account_interface: AccountInterface.new(state),
        sender: account_address,
        originator: account_address,
        available_gas: 100_000_000,
        gas_price: 1,
        endowment: 5,
        init_code: build_sample_code(),
        stack_depth: 5,
        block_header: %Block.Header{nonce: 1}
      }

      assert {:error, {^state, 0, sub_state}} = Contract.create(params)
      assert SubState.empty?(sub_state)
    end
  end

  defp build_sample_code do
    assembly = [
      :push1,
      3,
      :push1,
      5,
      :add,
      :push1,
      0x00,
      :mstore,
      :push1,
      32,
      :push1,
      0,
      :return
    ]

    MachineCode.compile(assembly)
  end
end
