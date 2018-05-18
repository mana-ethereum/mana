defmodule Blockchain.TransactionTest do
  use ExUnit.Case, async: true
  use EthCommonTest.Harness

  doctest Blockchain.Transaction

  alias ExthCrypto.Hash.Keccak
  alias Blockchain.{Account, Transaction, Contract}
  alias Blockchain.Transaction.Signature
  alias MerklePatriciaTree.Trie

  @forks ~w(
    Byzantium
    Constantinople
    EIP150
    EIP158
    Frontier
    Homestead
  )

  @forks_that_require_chain_id ~w(
    Byzantium
    Constantinople
    EIP158
  )

  @mainnet_chain_id 1

  define_common_tests(
    "TransactionTests",
    [
      ignore: [
        "ttWrongRLP/",
        "ttSignature/TransactionWithTooFewRLPElements.json",
        "ttSignature/TransactionWithTooManyRLPElements.json"
      ]
    ],
    fn test_name, test_data ->
      parsed_test = parse_test(test_data, test_name)

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

  defp chain_id_for_fork(fork) do
    if Enum.member?(@forks_that_require_chain_id, fork) do
      @mainnet_chain_id
    else
      nil
    end
  end

  defp parse_test(test, test_name) do
    rlp = test[test_name]["rlp"] |> maybe_hex()

    transaction =
      rlp
      |> ExRLP.decode()
      |> Transaction.deserialize()

    %{
      tests_by_fork: organize_tests_by_fork(test[test_name]),
      rlp: rlp,
      transaction: transaction
    }
  end

  defp organize_tests_by_fork(tests) do
    tests
    |> Map.take(@forks)
    |> Enum.map(fn {fork, fork_tests} ->
      {
        fork,
        Enum.map(fork_tests, fn {key_to_test, value} ->
          {String.to_atom(key_to_test), maybe_hex(value)}
        end)
        |> Enum.into(%{})
      }
    end)
    |> Enum.into(%{})
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

      assert tx ==
               tx
               |> Transaction.serialize()
               |> ExRLP.encode()
               |> ExRLP.decode()
               |> Transaction.deserialize()
    end

    test "for a transaction with a stop" do
      beneficiary_address = <<0x05::160>>
      private_key = <<1::256>>

      # Based on simple private key.
      sender_address =
        <<126, 95, 69, 82, 9, 26, 105, 18, 93, 93, 252, 183, 184, 194, 101, 144, 41, 57, 91, 223>>

      sender_account = %Account{balance: 400_000, nonce: 5}

      contract_address = Contract.new_contract_address(sender_address, 6)
      machine_code = EVM.MachineCode.compile([:stop])

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

      {state, gas_used, logs} =
        MerklePatriciaTree.Test.random_ets_db()
        |> Trie.new()
        |> Account.put_account(sender_address, sender_account)
        |> Transaction.execute_transaction(tx, %Block.Header{beneficiary: beneficiary_address})

      expected_sender = %Account{balance: 240_983, nonce: 6}
      expected_beneficiary = %Account{balance: 159_012}
      expected_contract = %Account{balance: 5}

      assert gas_used == 53004
      assert logs == []

      assert Account.get_account(state, sender_address) == expected_sender
      assert Account.get_account(state, beneficiary_address) == expected_beneficiary
      assert Account.get_account(state, contract_address) == expected_contract
    end
  end
end
