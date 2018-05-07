defmodule Blockchain.TransactionTest do
  use ExUnit.Case, async: true
  use EthCommonTest.Harness
  doctest Blockchain.Transaction

  require Logger

  alias Blockchain.Transaction
  alias Blockchain.Transaction.Signature

  @chains ~w(
    Byzantium
    Constantinople
    EIP150
    EIP158
    Frontier
    Homestead
  )

  define_common_tests "TransactionTests/ttAddress", [], fn test_name, test_data ->
    parsed_test = parse_test(test_data, test_name)

    for {_network, test} <- parsed_test.tests_by_network do
      for {method, value} <- test do
        case method do
          :hash ->
            assert BitHelper.kec(parsed_test.rlp) == value

          :sender ->
            assert Signature.sender(parsed_test.transaction) == {:ok, value}
        end
      end
    end
  end

  define_common_tests "TransactionTests/ttData", [except: ["String10MbData"]], fn test_name, test_data ->
    parsed_test = parse_test(test_data, test_name)

    for {_network, test} <- parsed_test.tests_by_network do
      for {method, value} <- test do
        case method do
          :hash ->
            assert BitHelper.kec(parsed_test.rlp) == value

          :sender ->
            assert Signature.sender(parsed_test.transaction) == {:ok, value}
        end
      end
    end
  end

  define_common_tests "TransactionTests/ttGasLimit", [], fn test_name, test_data ->
    parsed_test = parse_test(test_data, test_name)

    for {_network, test} <- parsed_test.tests_by_network do
      for {method, value} <- test do
        case method do
          :hash ->
            assert BitHelper.kec(parsed_test.rlp) == value

          :sender ->
            if parsed_test.transaction.v < 30 do
              assert Signature.sender(parsed_test.transaction) == {:ok, value}
            end
        end
      end
    end
  end

  define_common_tests "TransactionTests/ttGasPrice", [], fn test_name, test_data ->
    parsed_test = parse_test(test_data, test_name)

    for {_network, test} <- parsed_test.tests_by_network do
      for {method, value} <- test do
        case method do
          :hash ->
            assert BitHelper.kec(parsed_test.rlp) == value

          :sender ->
            assert Signature.sender(parsed_test.transaction) == {:ok, value}
        end
      end
    end
  end

  define_common_tests "TransactionTests/ttNonce", [], fn test_name, test_data ->
    parsed_test = parse_test(test_data, test_name)

    for {_network, test} <- parsed_test.tests_by_network do
      for {method, value} <- test do
        case method do
          :hash ->
            assert BitHelper.kec(parsed_test.rlp) == value

          :sender ->
            assert Signature.sender(parsed_test.transaction) == {:ok, value}
        end
      end
    end
  end


  define_common_tests "TransactionTests/ttRSValue", [], fn test_name, test_data ->
    parsed_test = parse_test(test_data, test_name)

    for {_network, test} <- parsed_test.tests_by_network do
      for {method, value} <- test do
        case method do
          :hash ->
            assert BitHelper.kec(parsed_test.rlp) == value

          :sender ->
            if parsed_test.transaction.v < 30 do
              assert Signature.sender(parsed_test.transaction) == {:ok, value}
            end
        end
      end
    end
  end

  define_common_tests "TransactionTests/ttSignature", [except: ["TransactionWithTooFewRLPElements", "TransactionWithTooManyRLPElements"]],
    fn test_name, test_data ->

    parsed_test = parse_test(test_data, test_name)

    for {_network, test} <- parsed_test.tests_by_network do
      for {method, value} <- test do
        case method do
          :hash ->
            assert BitHelper.kec(parsed_test.rlp) == value

          :sender ->
            if parsed_test.transaction.v < 30 do
              assert Signature.sender(parsed_test.transaction) == {:ok, value}
            end
        end
      end
    end
  end

  define_common_tests "TransactionTests/ttVValue", [], fn test_name, test_data ->
    parsed_test = parse_test(test_data, test_name)

    for {_network, test} <- parsed_test.tests_by_network do
      for {method, value} <- test do
        case method do
          :hash ->
            assert BitHelper.kec(parsed_test.rlp) == value

          :sender ->
            if parsed_test.transaction.v < 30 do
              assert Signature.sender(parsed_test.transaction) == {:ok, value}
            end
        end
      end
    end
  end

  define_common_tests "TransactionTests/ttValue", [], fn test_name, test_data ->
    parsed_test = parse_test(test_data, test_name)

    for {_network, test} <- parsed_test.tests_by_network do
      for {method, value} <- test do
        case method do
          :hash ->
            assert BitHelper.kec(parsed_test.rlp) == value

          :sender ->
            assert Signature.sender(parsed_test.transaction) == {:ok, value}
        end
      end
    end
  end

  defp parse_test(test, test_name) do
    rlp = test[test_name]["rlp"] |> maybe_hex()

    transaction =
        rlp
        |> ExRLP.decode()
        |> Transaction.deserialize()

    %{
      tests_by_network: organize_tests_by_chains(test[test_name]),
      rlp:  rlp,
      transaction: transaction,
    }
  end

  defp organize_tests_by_chains(tests) do
    tests
    |> Map.take(@chains)
    |> Enum.map(fn {network, test} ->
      {
        network,
        Enum.map(test, fn {key_to_test, value} ->
          { String.to_atom(key_to_test), maybe_hex(value) }
        end)
        |> Enum.into(%{})
      }
    end)
    |> Enum.into(%{})
  end

  describe "when handling transactions" do
    test "serialize and deserialize" do
      trx = %Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1::160>>, value: 8, v: 27, r: 9, s: 10, data: "hi"}

      assert trx == trx |> Transaction.serialize |> ExRLP.encode |> ExRLP.decode |> Transaction.deserialize
    end

    test "for a transaction with a stop" do
      beneficiary = <<0x05::160>>
      private_key = <<1::256>>
      sender = <<126, 95, 69, 82, 9, 26, 105, 18, 93, 93, 252, 183, 184, 194, 101, 144, 41, 57, 91, 223>> # based on simple private key
      contract_address = Blockchain.Contract.new_contract_address(sender, 6)
      machine_code = EVM.MachineCode.compile([:stop])
      trx = %Blockchain.Transaction{nonce: 5, gas_price: 3, gas_limit: 100_000, to: <<>>, value: 5, init: machine_code}
            |> Blockchain.Transaction.Signature.sign_transaction(private_key)

      {state, gas_used, logs} = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
        |> Blockchain.Account.put_account(sender, %Blockchain.Account{balance: 400_000, nonce: 5})
        |> Blockchain.Transaction.execute_transaction(trx, %Block.Header{beneficiary: beneficiary})

      assert gas_used == 53004
      assert logs == []
      assert Blockchain.Account.get_accounts(state, [sender, beneficiary, contract_address]) ==
        [
          %Blockchain.Account{balance: 240983, nonce: 6}, %Blockchain.Account{balance: 159012}, %Blockchain.Account{balance: 5}
        ]
    end
  end
end
