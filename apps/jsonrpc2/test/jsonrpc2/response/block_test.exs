defmodule JSONRPC2.Response.BlockTest do
  use ExUnit.Case, async: true

  alias JSONRPC2.Response.Block
  alias JSONRPC2.TestFactory

  describe "new/1" do
    test "creates response block from internal block" do
      internal_block = TestFactory.build(:block)

      response_block = Block.new(internal_block, false)

      assert response_block == %Block{
               extraData: "",
               hash: "0x0000000000000000000000000000000000000000000000000000000000000010",
               logsBloom:
                 "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
               miner: "0x0000000000000000000000000000000000000010",
               nonce: "0x0000000000000000",
               parentHash: "0x0000000000000000000000000000000000000000000000000000000000000010",
               receiptsRoot: "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
               sha3Uncles: "0x0000000000000000000000000000000000000000000000000000000000000010",
               stateRoot: "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
               transactions: [],
               transactionsRoot:
                 "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
               uncles: [],
               difficulty: "0x01",
               gasLimit: "0x00",
               gasUsed: "0x00",
               number: "0x01",
               size: "0x00",
               timestamp: "0x01",
               totalDifficulty: "0x00"
             }
    end

    test "encodes full transactions" do
      transaction1 = TestFactory.build(:transaction)
      transaction2 = TestFactory.build(:transaction)

      internal_block = TestFactory.build(:block, transactions: [transaction1, transaction2])

      response_block = Block.new(internal_block, true)

      assert response_block.transactions == [
               %JSONRPC2.Response.Transaction{
                 blockHash: "0x0000000000000000000000000000000000000000000000000000000000000010",
                 blockNumber: "0x01",
                 from: "0x619f56e8bed07fe196c0dbc41b52e2bc64817b3a",
                 gas: "0x07",
                 gasPrice: "0x06",
                 hash: "0x71024c28d1404f5d5fe3458b71b02d799f6d6aba29e285857732c0d06ebf3b08",
                 input: "0x01",
                 nonce: "0x05",
                 r: "0x55fa77ee62e6c42e83b4f868c1e41643e45fd6f02a381a663318884751cb690a",
                 s: "0x7bd63c407cea7d619d598fb5766980ab8497b1b11c26d8bc59a132af96317793",
                 to: "0x",
                 transactionIndex: "0x00",
                 v: "0x1b",
                 value: "0x05"
               },
               %JSONRPC2.Response.Transaction{
                 blockHash: "0x0000000000000000000000000000000000000000000000000000000000000010",
                 blockNumber: "0x01",
                 from: "0x619f56e8bed07fe196c0dbc41b52e2bc64817b3a",
                 gas: "0x07",
                 gasPrice: "0x06",
                 hash: "0x71024c28d1404f5d5fe3458b71b02d799f6d6aba29e285857732c0d06ebf3b08",
                 input: "0x01",
                 nonce: "0x05",
                 r: "0x55fa77ee62e6c42e83b4f868c1e41643e45fd6f02a381a663318884751cb690a",
                 s: "0x7bd63c407cea7d619d598fb5766980ab8497b1b11c26d8bc59a132af96317793",
                 to: "0x",
                 transactionIndex: "0x00",
                 v: "0x1b",
                 value: "0x05"
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
               "{\"difficulty\":\"0x01\",\"extraData\":\"\",\"gasLimit\":\"0x00\",\"gasUsed\":\"0x00\",\"hash\":\"0x0000000000000000000000000000000000000000000000000000000000000010\",\"logsBloom\":\"0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000\",\"miner\":\"0x0000000000000000000000000000000000000010\",\"nonce\":\"0x0000000000000000\",\"number\":\"0x01\",\"parentHash\":\"0x0000000000000000000000000000000000000000000000000000000000000010\",\"receiptsRoot\":\"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421\",\"sha3Uncles\":\"0x0000000000000000000000000000000000000000000000000000000000000010\",\"size\":\"0x00\",\"stateRoot\":\"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421\",\"timestamp\":\"0x01\",\"totalDifficulty\":\"0x00\",\"transactions\":[],\"transactionsRoot\":\"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421\",\"uncles\":[]}"
    end
  end
end
