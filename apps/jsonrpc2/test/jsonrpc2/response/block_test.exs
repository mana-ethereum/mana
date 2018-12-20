defmodule JSONRPC2.Response.BlockTest do
  use ExUnit.Case, async: true

  alias JSONRPC2.Response.Block
  alias JSONRPC2.TestFactory

  describe "new/1" do
    test "creates response block from internal block" do
      internal_block = TestFactory.build(:block)

      response_block = Block.new(internal_block, false)

      assert response_block == %JSONRPC2.Response.Block{
               difficulty: "0x1",
               gasLimit: "0x0",
               gasUsed: "0x0",
               number: "0x1",
               receiptsRoot: "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
               size: "0x0",
               stateRoot: "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
               timestamp: "0x1",
               totalDifficulty: "0x0",
               transactions: [],
               transactionsRoot:
                 "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
               uncles: [],
               extraData: "0x",
               hash: "0x0000000000000000000000000000000000000000000000000000000000000010",
               logsBloom:
                 "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
               miner: "0x0000000000000000000000000000000000000010",
               nonce: "0x0000000000000000",
               parentHash: "0x0000000000000000000000000000000000000000000000000000000000000010",
               sha3Uncles: "0x0000000000000000000000000000000000000000000000000000000000000010"
             }
    end

    test "encodes full transactions" do
      transaction1 = TestFactory.build(:transaction)
      transaction2 = TestFactory.build(:transaction)

      internal_block = TestFactory.build(:block, transactions: [transaction1, transaction2])

      response_block = Block.new(internal_block, true)

      assert response_block.transactions == [
               %JSONRPC2.Response.Transaction{
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
               },
               %JSONRPC2.Response.Transaction{
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
             ]
    end

    test "encodes only transaction hashes" do
      transaction1 = TestFactory.build(:transaction)
      transaction2 = TestFactory.build(:transaction)

      internal_block = TestFactory.build(:block, transactions: [transaction1, transaction2])

      response_block = Block.new(internal_block, false)

      assert response_block.transactions == [
               "0x7f71d14c13c402ce13c6f063b83e085f097a878e33163d6146cece277936531b",
               "0x7f71d14c13c402ce13c6f063b83e085f097a878e33163d6146cece277936531b"
             ]
    end

    test "returns uncle hashes" do
      internal_block =
        TestFactory.build(:block, ommers: [TestFactory.build(:header), TestFactory.build(:header)])

      response_block = Block.new(internal_block)

      assert response_block.uncles == [
               "0xa33912876669bdef5f8e9bcd54b32864c2cd6af57370f06dd17472942c5728a5",
               "0xa33912876669bdef5f8e9bcd54b32864c2cd6af57370f06dd17472942c5728a5"
             ]
    end

    test "correctly encodes to json" do
      internal_block = TestFactory.build(:block)

      json_block =
        internal_block
        |> Block.new(false)
        |> Jason.encode!()

      assert json_block ==
               "{\"difficulty\":\"0x1\",\"extraData\":\"0x\",\"gasLimit\":\"0x0\",\"gasUsed\":\"0x0\",\"hash\":\"0x0000000000000000000000000000000000000000000000000000000000000010\",\"logsBloom\":\"0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000\",\"miner\":\"0x0000000000000000000000000000000000000010\",\"nonce\":\"0x0000000000000000\",\"number\":\"0x1\",\"parentHash\":\"0x0000000000000000000000000000000000000000000000000000000000000010\",\"receiptsRoot\":\"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421\",\"sha3Uncles\":\"0x0000000000000000000000000000000000000000000000000000000000000010\",\"size\":\"0x0\",\"stateRoot\":\"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421\",\"timestamp\":\"0x1\",\"totalDifficulty\":\"0x0\",\"transactions\":[],\"transactionsRoot\":\"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421\",\"uncles\":[]}"
    end
  end
end
