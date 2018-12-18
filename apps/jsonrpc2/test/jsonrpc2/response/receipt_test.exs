defmodule JSONRPC2.Response.ReceiptTest do
  use ExUnit.Case, async: true

  alias JSONRPC2.Response.Receipt
  alias JSONRPC2.TestFactory

  describe "new/4" do
    test "creates response receipt from internal block" do
      transaction = TestFactory.build(:transaction)
      block = TestFactory.build(:block, transactions: [transaction])
      receipt = TestFactory.build(:receipt)

      response_receipt = Receipt.new(receipt, transaction, block)

      assert response_receipt == %JSONRPC2.Response.Receipt{
               blockHash: "0x0000000000000000000000000000000000000000000000000000000000000010",
               blockNumber: "0x01",
               contractAddress: "",
               cumulativeGasUsed: "0x03e8",
               from: "0x619f56e8bed07fe196c0dbc41b52e2bc64817b3a",
               gasUsed: "0x03e8",
               logs: [],
               logsBloom:
                 "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
               root: nil,
               status: "0x01",
               to: "0x",
               transactionHash:
                 "0x71024c28d1404f5d5fe3458b71b02d799f6d6aba29e285857732c0d06ebf3b08",
               transactionIndex: "0x00"
             }
    end
  end
end
