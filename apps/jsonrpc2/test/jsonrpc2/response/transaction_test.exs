defmodule JSONRPC2.Response.TransactionTest do
  use ExUnit.Case, async: true

  alias JSONRPC2.Response.Transaction

  import JSONRPC2.TestFactory

  describe "new/2" do
    test "creates response transacton from internal transaction" do
      internal_transaction = build(:transaction)
      internal_block = build(:block, transactions: [internal_transaction])

      response_transaction = Transaction.new(internal_transaction, internal_block)

      assert response_transaction == %JSONRPC2.Response.Transaction{
               blockNumber: "0x1",
               from: "0x619f56e8bed07fe196c0dbc41b52e2bc64817b3a",
               gas: "0x7",
               gasPrice: "0x6",
               nonce: "0x5",
               r: "0x55fa77ee62e6c42e83b4f868c1e41643e45fd6f02a381a663318884751cb690a",
               s: "0x7bd63c407cea7d619d598fb5766980ab8497b1b11c26d8bc59a132af96317793",
               transactionIndex: "0x0",
               v: "0x1b",
               value: "0x5",
               blockHash: "0x0000000000000000000000000000000000000000000000000000000000000010",
               hash: "0x7f71d14c13c402ce13c6f063b83e085f097a878e33163d6146cece277936531b",
               input: "0x01",
               to: "0x"
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
               "{\"blockHash\":\"0x0000000000000000000000000000000000000000000000000000000000000010\",\"blockNumber\":\"0x1\",\"from\":\"0x619f56e8bed07fe196c0dbc41b52e2bc64817b3a\",\"gas\":\"0x7\",\"gasPrice\":\"0x6\",\"hash\":\"0x7f71d14c13c402ce13c6f063b83e085f097a878e33163d6146cece277936531b\",\"input\":\"0x01\",\"nonce\":\"0x5\",\"r\":\"0x55fa77ee62e6c42e83b4f868c1e41643e45fd6f02a381a663318884751cb690a\",\"s\":\"0x7bd63c407cea7d619d598fb5766980ab8497b1b11c26d8bc59a132af96317793\",\"to\":\"0x\",\"transactionIndex\":\"0x0\",\"v\":\"0x1b\",\"value\":\"0x5\"}"
    end
  end
end
