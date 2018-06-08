defmodule Blockchain.Contract.CreateContractTest do
  use ExUnit.Case
  doctest Blockchain.Contract.CreateContract

  alias Blockchain.{Account, Contract}
  alias EVM.{SubState, MachineCode}
  alias MerklePatriciaTree.{Trie, DB}

  # TODO: Add rich tests for contract creation

  setup do
    db = MerklePatriciaTree.Test.random_ets_db(:contract_test)
    {:ok, %{db: db}}
  end

  describe "execute/1" do
    test "creates a new contract", %{db: db} do
      account = %Account{balance: 11, nonce: 5}

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

      init_code = MachineCode.compile(assembly)

      state =
        db
        |> Trie.new()
        |> Account.put_account(<<0x10::160>>, account)

      params = %Contract.CreateContract{
        state: state,
        sender: <<0x10::160>>,
        originator: <<0x10::160>>,
        available_gas: 1000,
        gas_price: 1,
        endowment: 5,
        init_code: init_code,
        stack_depth: 5,
        block_header: %Block.Header{nonce: 1}
      }

      {state, gas, sub_state} = Contract.create(params)

      expected_root_hash =
        <<118, 141, 248, 163, 131, 53, 35, 217, 52, 119, 112, 222, 52, 83, 19, 139, 167, 201, 222,
          169, 179, 183, 141, 85, 212, 0, 169, 59, 19, 88, 229, 99>>

      assert state == %Trie{db: {DB.ETS, :contract_test}, root_hash: expected_root_hash}
      assert gas == 976
      assert SubState.empty?(sub_state)

      addresses = [<<0x10::160>>, Contract.Address.new(<<0x10::160>>, 5)]
      actual_accounts = Account.get_accounts(state, addresses)

      expected_accounts = [
        %Account{balance: 6, nonce: 5},
        %Account{
          balance: 5,
          nonce: 1,
          code_hash:
            <<243, 247, 169, 254, 54, 79, 170, 185, 59, 33, 109, 165, 10, 50, 20, 21, 79, 34, 160,
              162, 180, 21, 178, 58, 132, 200, 22, 158, 139, 99, 110, 227>>
        }
      ]

      assert actual_accounts == expected_accounts

      contract_address = Contract.Address.new(<<0x10::160>>, 5)
      assert Account.get_machine_code(state, contract_address) == {:ok, <<0x08::256>>}
      assert state |> Trie.Inspector.all_keys() |> Enum.count() == 2
    end
  end
end
