defmodule Blockchain.TransactionTest do
  use ExUnit.Case, async: true
  import EthCommonTest.Helpers

  doctest Blockchain.Transaction

  alias Blockchain.{Account, Chain, Transaction}
  alias Blockchain.Account.Repo
  alias EVM.MachineCode
  alias ExthCrypto.Hash.Keccak
  alias MerklePatriciaTree.Trie

  @forks ~w(
    Byzantium
    Constantinople
    TangerineWhistle
    SpuriousDragon
    Frontier
    Homestead
  )

  @forks_that_require_chain_id ~w(
    Byzantium
    Constantinople
    EIP158
  )

  @mainnet_chain_id 1

  test "eth common tests" do
    EthCommonTest.Helpers.run_common_tests(
      "TransactionTests",
      &ExUnit.Assertions.flunk/1,
      fn test_name, test_case ->
        parsed_test = parse_test(test_name, test_case)

        for {fork, test} <- parsed_test.tests_by_fork do
          chain_id = chain_id_for_fork(fork)

          for {method, value} <- test do
            case method do
              :hash ->
                assert Keccak.kec(parsed_test.rlp) == value

              :sender ->
                assert Signature.sender(parsed_test.transaction, chain_id) == {:ok, value}
            end
          end
        end
      end
    )
  end

  defp chain_id_for_fork(fork) do
    if Enum.member?(@forks_that_require_chain_id, fork) do
      @mainnet_chain_id
    else
      nil
    end
  end

  defp parse_test(test_name, test_case) do
    rlp = maybe_hex(test_case["rlp"])

    transaction =
      rlp
      |> ExRLP.decode()
      |> Transaction.deserialize()

    %{
      tests_by_fork: organize_tests_by_fork(test_case),
      rlp: rlp,
      transaction: transaction
    }
  end

  defp organize_tests_by_fork(tests) do
    tests
    |> Map.take(@forks)
    |> Enum.into(%{}, fn {fork, fork_tests} ->
      {
        fork,
        fork_tests
        |> Enum.into(%{}, fn {key_to_test, value} ->
          {String.to_atom(key_to_test), maybe_hex(value)}
        end)
      }
    end)
  end

  describe "when handling transactions" do
    test "serialize and deserialize" do
      tx = %Transaction{
        nonce: 5,
        gas_price: 6,
        gas_limit: 7,
        to: <<1::160>>,
        value: 8,
        v: 27,
        r: 9,
        s: 10,
        data: "hi"
      }

      expected_tx =
        tx
        |> Transaction.serialize()
        |> ExRLP.encode()
        |> ExRLP.decode()
        |> Transaction.deserialize()

      assert tx == expected_tx
    end
  end

  describe "input_data/1" do
    test "returns the init data when it is a contract creation transaction" do
      machine_code = MachineCode.compile([:stop])
      tx = %Transaction{to: <<>>, init: machine_code}

      assert Transaction.input_data(tx) == machine_code
    end

    test "returns the data when it is a message call transaction" do
      machine_code = MachineCode.compile([:stop])
      tx = %Transaction{to: <<1::160>>, data: machine_code}

      assert Transaction.input_data(tx) == machine_code
    end
  end

  describe "execute/3" do
    test "creates a new contract" do
      beneficiary = <<0x05::160>>
      private_key = <<1::256>>
      # based on simple private key
      sender =
        <<126, 95, 69, 82, 9, 26, 105, 18, 93, 93, 252, 183, 184, 194, 101, 144, 41, 57, 91, 223>>

      contract_address = Account.Address.new(sender, 6)

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

      machine_code = MachineCode.compile(assembly)

      unsigned_tx = %Transaction{
        nonce: 5,
        gas_price: 3,
        gas_limit: 100_000,
        to: <<>>,
        value: 5,
        init: machine_code
      }

      tx = Transaction.Signature.sign_transaction(unsigned_tx, private_key)

      chain = Chain.test_config("Frontier")

      {account_repo, gas, receipt} =
        MerklePatriciaTree.Test.random_ets_db()
        |> Trie.new()
        |> Account.put_account(sender, %Account{balance: 400_000, nonce: 5})
        |> Transaction.execute(tx, %Block.Header{beneficiary: beneficiary}, chain)

      state = Repo.commit(account_repo).state

      assert gas == 28_180
      assert receipt.logs == []

      addresses = [sender, beneficiary, contract_address]
      actual_accounts = Account.get_accounts(state, addresses)

      expected_accounts = [
        %Blockchain.Account{balance: 315_455, nonce: 6},
        %Blockchain.Account{balance: 84_540},
        %Blockchain.Account{
          balance: 5,
          nonce: 0,
          code_hash:
            <<243, 247, 169, 254, 54, 79, 170, 185, 59, 33, 109, 165, 10, 50, 20, 21, 79, 34, 160,
              162, 180, 21, 178, 58, 132, 200, 22, 158, 139, 99, 110, 227>>
        }
      ]

      assert actual_accounts == expected_accounts
    end

    test "executes a message call to a contract" do
      beneficiary = <<0x05::160>>
      private_key = <<1::256>>
      # based on simple private key
      sender =
        <<126, 95, 69, 82, 9, 26, 105, 18, 93, 93, 252, 183, 184, 194, 101, 144, 41, 57, 91, 223>>

      contract_address = Account.Address.new(sender, 6)

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
        0,
        :push1,
        32,
        :return
      ]

      machine_code = MachineCode.compile(assembly)

      unsigned_tx = %Transaction{
        nonce: 5,
        gas_price: 3,
        gas_limit: 100_000,
        to: contract_address,
        value: 5,
        data: machine_code
      }

      tx = Transaction.Signature.sign_transaction(unsigned_tx, private_key)

      db = MerklePatriciaTree.Test.random_ets_db()

      chain = Chain.test_config("Frontier")

      {account_repo, gas, receipt} =
        db
        |> Trie.new()
        |> Account.put_account(sender, %Account{balance: 400_000, nonce: 5})
        |> Account.put_code(contract_address, machine_code)
        |> Transaction.execute(tx, %Block.Header{beneficiary: beneficiary}, chain)

      state = Repo.commit(account_repo).state

      assert gas == 21_780
      assert receipt.logs == []

      addresses = [sender, beneficiary, contract_address]
      actual_accounts = Account.get_accounts(state, addresses)

      expected_accounts = [
        %Account{balance: 334_655, nonce: 6},
        %Account{balance: 65_340},
        %Account{
          balance: 5,
          code_hash:
            <<216, 114, 80, 103, 17, 50, 164, 75, 162, 123, 123, 99, 162, 105, 226, 15, 215, 200,
              136, 216, 29, 106, 193, 119, 1, 173, 138, 37, 219, 39, 23, 231>>
        }
      ]

      assert actual_accounts == expected_accounts
    end

    test "for a transaction with a stop" do
      beneficiary_address = <<0x05::160>>
      private_key = <<1::256>>

      # Based on simple private key.
      sender_address =
        <<126, 95, 69, 82, 9, 26, 105, 18, 93, 93, 252, 183, 184, 194, 101, 144, 41, 57, 91, 223>>

      sender_account = %Account{balance: 400_000, nonce: 5}

      contract_address = Account.Address.new(sender_address, 6)
      machine_code = MachineCode.compile([:stop])

      tx =
        %Transaction{
          nonce: 5,
          gas_price: 3,
          gas_limit: 100_000,
          to: <<>>,
          value: 5,
          init: machine_code
        }
        |> Transaction.Signature.sign_transaction(private_key)

      chain = Chain.test_config("Frontier")

      {account_repo, gas_used, receipt} =
        MerklePatriciaTree.Test.random_ets_db()
        |> Trie.new()
        |> Account.put_account(sender_address, sender_account)
        |> Transaction.execute(tx, %Block.Header{beneficiary: beneficiary_address}, chain)

      state = Repo.commit(account_repo).state

      expected_sender = %Account{balance: 336_983, nonce: 6}
      expected_beneficiary = %Account{balance: 63_012}
      expected_contract = %Account{balance: 5, nonce: 0}

      assert gas_used == 21_004
      assert receipt.logs == []

      assert Account.get_account(state, sender_address) == expected_sender
      assert Account.get_account(state, beneficiary_address) == expected_beneficiary
      assert Account.get_account(state, contract_address) == expected_contract
    end
  end

  describe "execute transaction with revert (Byzantium)" do
    test "reverts message call state except for gas used, increments nonce, and marks tx status as failed (0)" do
      chain = Chain.test_config("Byzantium")
      private_key = <<1::256>>
      gas_price = 3

      beneficiary = %{address: <<0x05::160>>}

      sender = %{
        address:
          <<126, 95, 69, 82, 9, 26, 105, 18, 93, 93, 252, 183, 184, 194, 101, 144, 41, 57, 91,
            223>>,
        nonce: 6
      }

      contract_address = Account.Address.new(sender.address, sender.nonce)

      machine_code =
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

      unsigned_tx = %Transaction{
        nonce: 5,
        gas_price: gas_price,
        gas_limit: 100_000,
        to: contract_address,
        value: 5,
        data: machine_code
      }

      tx = Transaction.Signature.sign_transaction(unsigned_tx, private_key)

      {account_repo, gas, receipt} =
        MerklePatriciaTree.Test.random_ets_db()
        |> Trie.new()
        |> Account.put_account(sender.address, %Account{balance: 400_000, nonce: sender.nonce})
        |> Account.put_code(contract_address, machine_code)
        |> Transaction.execute(tx, %Block.Header{beneficiary: beneficiary.address}, chain)

      state = Repo.commit(account_repo).state

      assert gas == 21_495
      assert receipt.logs == []

      sender_account = Account.get_account(state, sender.address)
      beneficiary_account = Account.get_account(state, beneficiary.address)
      contract_account = Account.get_account(state, contract_address)

      assert sender_account == %Account{
               balance: 400_000 - gas * gas_price,
               nonce: sender.nonce + 1
             }

      assert beneficiary_account == %Account{balance: gas * gas_price}
      assert contract_account == %Account{balance: 0, code_hash: Keccak.kec(machine_code)}
    end

    test "reverts contract creation state except for gas used, increments nonce, and marks tx status as failed (0)" do
      chain = Chain.test_config("Byzantium")
      private_key = <<1::256>>
      gas_price = 3

      beneficiary = %{address: <<0x05::160>>}

      sender = %{
        address:
          <<126, 95, 69, 82, 9, 26, 105, 18, 93, 93, 252, 183, 184, 194, 101, 144, 41, 57, 91,
            223>>,
        nonce: 6
      }

      machine_code =
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

      unsigned_tx = %Transaction{
        nonce: 5,
        gas_price: gas_price,
        gas_limit: 100_000,
        to: <<>>,
        value: 5,
        init: machine_code
      }

      tx = Transaction.Signature.sign_transaction(unsigned_tx, private_key)

      {account_repo, gas, receipt} =
        MerklePatriciaTree.Test.random_ets_db()
        |> Trie.new()
        |> Account.put_account(sender.address, %Account{balance: 400_000, nonce: sender.nonce})
        |> Transaction.execute(tx, %Block.Header{beneficiary: beneficiary.address}, chain)

      state = Repo.commit(account_repo).state

      assert gas == 53_495
      assert receipt.logs == []

      sender_account = Account.get_account(state, sender.address)
      beneficiary_account = Account.get_account(state, beneficiary.address)

      assert sender_account == %Account{
               balance: 400_000 - gas * gas_price,
               nonce: sender.nonce + 1
             }

      assert beneficiary_account == %Account{balance: gas * gas_price}

      contract_address = Account.Address.new(sender.address, sender.nonce)
      assert is_nil(Account.get_account(state, contract_address))
    end
  end
end
