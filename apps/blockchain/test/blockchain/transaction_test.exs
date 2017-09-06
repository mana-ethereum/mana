defmodule Blockchain.TransactionTest do
  use ExUnit.Case, async: true
  doctest Blockchain.Transaction
  alias Blockchain.Transaction

  describe "when handling transactions" do

    test "serialize and deserialize" do
      trx = %Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1::160>>, value: 8, v: 27, r: 9, s: 10, data: "hi"}

      assert trx == trx |> Transaction.serialize |> ExRLP.encode |> ExRLP.decode |> Transaction.deserialize
    end

    test "for a transaction with a stop" do
      beneficiary = <<0x05::160>>
      private_key = <<1::256>>
      sender = <<125, 110, 153, 187, 138, 191, 140, 192, 19, 187, 14, 145, 45, 11, 23, 101, 150, 254, 123, 136>> # based on simple private key
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
end