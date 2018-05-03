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

  define_common_tests "TransactionTests", fn test_name, test_data ->
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

  defp parse_test(test, test_name) do
    rlp = try do
      test[test_name]["rlp"] |> maybe_hex
    rescue
      ArgumentError -> nil
    end

    transaction = try do
        rlp
        |> ExRLP.decode
        |> Transaction.deserialize
    rescue
      _ -> nil
    end

    %{
      tests_by_network: test[test_name]
          |> Map.take(@chains)
          |> Enum.map(fn {network, test} -> {
            String.to_atom(network),
            test |>
            Enum.map(fn {key, value}->
              {String.to_atom(key), maybe_hex(value)}
            end)
            |> Enum.into(%{})
            }
          end)
          |> Enum.into(%{}),
      rlp:  rlp,
      transaction: transaction,
    }
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
      assert logs == ""
      assert Blockchain.Account.get_accounts(state, [sender, beneficiary, contract_address]) ==
        [
          %Blockchain.Account{balance: 240983, nonce: 6}, %Blockchain.Account{balance: 159012}, %Blockchain.Account{balance: 5}
        ]
    end
  end

  defp load_trx(trx_data) do
    to = trx_data["to"] |> maybe_address
    data = trx_data["data"] |> maybe_hex

    %Blockchain.Transaction{
      nonce: trx_data["nonce"] |> load_integer,
      gas_price: trx_data["gasPrice"] |> load_integer,
      gas_limit: trx_data["gasLimit"] |> load_integer,
      to: to,
      value: trx_data["value"] |> load_integer,
      v: trx_data["v"] |> load_integer,
      r: trx_data["r"] |> load_integer,
      s: trx_data["s"] |> load_integer,
      init: (if to == <<>>, do: data, else: <<>>),
      data: (if to == <<>>, do: <<>>, else: data)
    }
  end
end
