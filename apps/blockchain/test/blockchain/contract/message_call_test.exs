defmodule Blockchain.Contract.MessageCallTest do
  use ExUnit.Case
  doctest Blockchain.Contract.MessageCall

  alias Blockchain.{Account, Contract}
  alias EVM.{SubState, MachineCode}
  alias MerklePatriciaTree.{Trie, DB}
  alias Blockchain.Interface.AccountInterface

  setup do
    db = MerklePatriciaTree.Test.random_ets_db(:message_call_test)
    {:ok, %{db: db}}
  end

  describe "execute/1" do
    test "executes a message call to a contract", %{db: db} do
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

      code = MachineCode.compile(assembly)

      state =
        db
        |> Trie.new()
        |> Account.put_account(<<0x10::160>>, %Account{balance: 10})
        |> Account.put_account(<<0x20::160>>, %Account{balance: 20})
        |> Account.put_code(<<0x20::160>>, code)

      params = %Contract.MessageCall{
        account_interface: AccountInterface.new(state),
        sender: <<0x10::160>>,
        originator: <<0x10::160>>,
        recipient: <<0x20::160>>,
        contract: <<0x20::160>>,
        available_gas: 1000,
        gas_price: 1,
        value: 5,
        apparent_value: 5,
        data: <<1, 2, 3>>,
        stack_depth: 5,
        block_header: %Block.Header{nonce: 1}
      }

      {:ok, {state, gas, sub_state, output}} = Contract.message_call(params)

      expected_root_hash =
        <<163, 151, 95, 0, 149, 63, 81, 220, 74, 101, 219, 175, 240, 97, 153, 167, 249, 229, 144,
          75, 101, 233, 126, 177, 8, 188, 105, 165, 28, 248, 67, 156>>

      expected_state = %Trie{
        db: {DB.ETS, :message_call_test},
        root_hash: expected_root_hash
      }

      assert state == expected_state
      assert gas == 976
      assert SubState.empty?(sub_state)
      assert output == <<0x08::256>>

      addresses = [<<0x10::160>>, <<0x20::160>>]
      actual_accounts = Blockchain.Account.get_accounts(state, addresses)

      expected_accounts = [
        %Account{balance: 5},
        %Account{
          balance: 25,
          code_hash:
            <<135, 110, 129, 59, 111, 55, 97, 45, 238, 64, 115, 133, 37, 188, 196, 107, 160, 151,
              31, 167, 249, 187, 243, 251, 173, 170, 244, 204, 78, 134, 208, 239>>
        }
      ]

      assert actual_accounts == expected_accounts
      assert state |> MerklePatriciaTree.Trie.Inspector.all_keys() |> Enum.count() == 2
    end

    test "returns error tuple if message call fails", %{db: db} do
      code = MachineCode.compile([:push1, 2, :add])

      state =
        db
        |> Trie.new()
        |> Account.put_account(<<0x10::160>>, %Account{balance: 10})
        |> Account.put_account(<<0x20::160>>, %Account{balance: 20})
        |> Account.put_code(<<0x20::160>>, code)

      params = %Contract.MessageCall{
        account_interface: AccountInterface.new(state),
        sender: <<0x10::160>>,
        originator: <<0x10::160>>,
        recipient: <<0x20::160>>,
        contract: <<0x20::160>>,
        available_gas: 1000,
        gas_price: 1,
        value: 5,
        apparent_value: 5,
        data: <<1, 2, 3>>,
        stack_depth: 5,
        block_header: %Block.Header{nonce: 1}
      }

      assert {:error, {^state, gas, sub_state, output}} = Contract.message_call(params)
      assert gas == 0
      assert SubState.empty?(sub_state)
      assert output == :failed
    end

    test "returns error tuple if message call is reverted", %{db: db} do
      code =
        MachineCode.compile([
          :push1,
          3,
          :push1,
          5,
          :add,
          :push1,
          0x00,
          :revert
        ])

      state =
        db
        |> Trie.new()
        |> Account.put_account(<<0x10::160>>, %Account{balance: 10})
        |> Account.put_account(<<0x20::160>>, %Account{balance: 20})
        |> Account.put_code(<<0x20::160>>, code)

      params = %Contract.MessageCall{
        account_interface: AccountInterface.new(state),
        sender: <<0x10::160>>,
        originator: <<0x10::160>>,
        recipient: <<0x20::160>>,
        contract: <<0x20::160>>,
        available_gas: 1000,
        gas_price: 1,
        value: 5,
        apparent_value: 5,
        data: <<1, 2, 3>>,
        stack_depth: 5,
        block_header: %Block.Header{nonce: 1},
        config: EVM.Configuration.Byzantium.new()
      }

      assert {:error, {^state, gas, sub_state, output}} = Contract.message_call(params)
      assert gas == 985
      assert SubState.empty?(sub_state)
      assert output == :failed
    end
  end
end
