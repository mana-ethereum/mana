defmodule JSONRPC2.Response.TransactionTest do
  use ExUnit.Case, async: true

  alias JSONRPC2.Response.Transaction

  import JSONRPC2.TestFactory

  describe "new/2" do
    test "creates response transacton from internal transaction" do
      internal_transaction = build(:transaction)
      internal_block = build(:block, transactions: [internal_transaction])

      response_transaction = Transaction.new(internal_transaction, internal_block)

      assert response_transaction == %Transaction{
               blockHash: "0x0000000000000000000000000000000000000000000000000000000000000010",
               blockNumber: "0x01",
               from: "",
               gas: "0x00",
               gasPrice: "0x00",
               hash: "0x7fde09421490beb00ee198097c5d6c9da3ad5625e3a68c121bd180f611e102b6",
               input: "0x",
               nonce: "0x00",
               r: "0x00",
               s: "0x01",
               to: "0x0000000000000000000000000000000000000010",
               transactionIndex: "0x00",
               v: "0x00",
               value: "0x00"
             }
    end

    test "correctly encodes to json" do
      internal_transaction = build(:transaction)
      internal_block = build(:block, transactions: [internal_transaction])

      json_transaction =
        internal_transaction
        |> Transaction.new(internal_block)
        |> Jason.encode!()

      assert json_transaction ==
               "{\"blockHash\":\"0x0000000000000000000000000000000000000000000000000000000000000010\",\"blockNumber\":\"0x01\",\"from\":\"\",\"gas\":\"0x00\",\"gasPrice\":\"0x00\",\"hash\":\"0x7fde09421490beb00ee198097c5d6c9da3ad5625e3a68c121bd180f611e102b6\",\"input\":\"0x\",\"nonce\":\"0x00\",\"r\":\"0x00\",\"s\":\"0x01\",\"to\":\"0x0000000000000000000000000000000000000010\",\"transactionIndex\":\"0x00\",\"v\":\"0x00\",\"value\":\"0x00\"}"
    end
  end
end
