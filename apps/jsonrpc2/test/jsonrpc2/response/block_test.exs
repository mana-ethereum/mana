defmodule JSONRPC2.Response.BlockTest do
  use ExUnit.Case, async: true

  alias JSONRPC2.Response.Block
  alias JSONRPC2.TestFactory

  describe "new/1" do
    test "creates response block from internal block" do
      internal_block = TestFactory.build(:block)

      response_block = Block.new(internal_block, false)

      assert response_block == %JSONRPC2.Response.Block{
               extraData: "",
               receiptsRoot: "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
               stateRoot: "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
               transactions: [],
               transactionsRoot:
                 "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
               uncles: [],
               difficulty: "0x1",
               gasLimit: "0x0",
               gasUsed: "0x0",
               hash: "0x10",
               logsBloom: "0x0",
               miner: "0x10",
               nonce: "0x0",
               number: "0x1",
               parentHash: "0x10",
               sha3Uncles: "0x10",
               size: "0x0",
               timestamp: "0x1",
               totalDifficulty: "0x0"
             }
    end

    test "encodes full transactions" do
      transaction1 = TestFactory.build(:transaction)
      transaction2 = TestFactory.build(:transaction)

      internal_block = TestFactory.build(:block, transactions: [transaction1, transaction2])

      response_block = Block.new(internal_block, true)

      assert response_block.transactions == [
               %JSONRPC2.Response.Transaction{
                 from: "0x619f56e8bed07fe196c0dbc41b52e2bc64817b3a",
                 hash: "0x71024c28d1404f5d5fe3458b71b02d799f6d6aba29e285857732c0d06ebf3b08",
                 r: "0x55fa77ee62e6c42e83b4f868c1e41643e45fd6f02a381a663318884751cb690a",
                 s: "0x7bd63c407cea7d619d598fb5766980ab8497b1b11c26d8bc59a132af96317793",
                 v: "0x1b",
                 blockHash: "0x10",
                 blockNumber: "0x1",
                 gas: "0x7",
                 gasPrice: "0x6",
                 input: "0x1",
                 nonce: "0x5",
                 to: "",
                 transactionIndex: "0x0",
                 value: "0x5"
               },
               %JSONRPC2.Response.Transaction{
                 from: "0x619f56e8bed07fe196c0dbc41b52e2bc64817b3a",
                 hash: "0x71024c28d1404f5d5fe3458b71b02d799f6d6aba29e285857732c0d06ebf3b08",
                 r: "0x55fa77ee62e6c42e83b4f868c1e41643e45fd6f02a381a663318884751cb690a",
                 s: "0x7bd63c407cea7d619d598fb5766980ab8497b1b11c26d8bc59a132af96317793",
                 v: "0x1b",
                 blockHash: "0x10",
                 blockNumber: "0x1",
                 gas: "0x7",
                 gasPrice: "0x6",
                 input: "0x1",
                 nonce: "0x5",
                 to: "",
                 transactionIndex: "0x0",
                 value: "0x5"
               }
             ]
    end

    test "encodes only transaction hashes" do
      transaction1 = TestFactory.build(:transaction)
      transaction2 = TestFactory.build(:transaction)

      internal_block = TestFactory.build(:block, transactions: [transaction1, transaction2])

      response_block = Block.new(internal_block, false)

      assert response_block.transactions == [
               "0x71024c28d1404f5d5fe3458b71b02d799f6d6aba29e285857732c0d06ebf3b08",
               "0x71024c28d1404f5d5fe3458b71b02d799f6d6aba29e285857732c0d06ebf3b08"
             ]
    end

    test "returns uncle hashes" do
      internal_block =
        TestFactory.build(:block, ommers: [TestFactory.build(:header), TestFactory.build(:header)])

      response_block = Block.new(internal_block)

      assert response_block.uncles == [
               <<163, 57, 18, 135, 102, 105, 189, 239, 95, 142, 155, 205, 84, 179, 40, 100, 194,
                 205, 106, 245, 115, 112, 240, 109, 209, 116, 114, 148, 44, 87, 40, 165>>,
               <<163, 57, 18, 135, 102, 105, 189, 239, 95, 142, 155, 205, 84, 179, 40, 100, 194,
                 205, 106, 245, 115, 112, 240, 109, 209, 116, 114, 148, 44, 87, 40, 165>>
             ]
    end

    test "correctly encodes to json" do
      internal_block = TestFactory.build(:block)

      json_block =
        internal_block
        |> Block.new(false)
        |> Jason.encode!()

      assert json_block ==
               "{\"difficulty\":\"0x1\",\"extraData\":\"\",\"gasLimit\":\"0x0\",\"gasUsed\":\"0x0\",\"hash\":\"0x10\",\"logsBloom\":\"0x0\",\"miner\":\"0x10\",\"nonce\":\"0x0\",\"number\":\"0x1\",\"parentHash\":\"0x10\",\"receiptsRoot\":\"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421\",\"sha3Uncles\":\"0x10\",\"size\":\"0x0\",\"stateRoot\":\"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421\",\"timestamp\":\"0x1\",\"totalDifficulty\":\"0x0\",\"transactions\":[],\"transactionsRoot\":\"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421\",\"uncles\":[]}"
    end
  end
end
