defmodule Blockchain.TransactionTest do
  use ExUnit.Case, async: true
  use EthCommonTest.Harness
  doctest Blockchain.Transaction

  alias ExthCrypto.Hash.Keccak
  alias Blockchain.Transaction
  alias Blockchain.Transaction.Signature

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
      trx = %Transaction{
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

      assert trx ==
               trx
               |> Transaction.serialize()
               |> ExRLP.encode()
               |> ExRLP.decode()
               |> Transaction.deserialize()
    end

    test "for a transaction with a stop" do
      beneficiary = <<0x05::160>>
      private_key = <<1::256>>
      # Based on simple private key.
      sender =
        <<126, 95, 69, 82, 9, 26, 105, 18, 93, 93, 252, 183, 184, 194, 101, 144, 41, 57, 91, 223>>

      contract_address = Blockchain.Contract.new_contract_address(sender, 6)
      machine_code = EVM.MachineCode.compile([:stop])

      trx =
        %Blockchain.Transaction{
          nonce: 5,
          gas_price: 3,
          gas_limit: 100_000,
          to: <<>>,
          value: 5,
          init: machine_code
        }
        |> Blockchain.Transaction.Signature.sign_transaction(private_key)

      {state, gas_used, logs} =
        MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
        |> Blockchain.Account.put_account(sender, %Blockchain.Account{balance: 400_000, nonce: 5})
        |> Blockchain.Transaction.execute_transaction(trx, %Block.Header{beneficiary: beneficiary})

      assert gas_used == 53004
      assert logs == []

      assert Blockchain.Account.get_accounts(state, [sender, beneficiary, contract_address]) ==
               [
                 %Blockchain.Account{balance: 240_983, nonce: 6},
                 %Blockchain.Account{balance: 159_012},
                 %Blockchain.Account{balance: 5}
               ]
    end
  end
end
