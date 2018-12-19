defmodule JSONRPC2.Response.ReceiptTest do
  use ExUnit.Case, async: true

  alias JSONRPC2.Response.Receipt
  alias JSONRPC2.TestFactory

  describe "new/4" do
    test "creates response receipt from internal block for contract creation transaction" do
      transaction = TestFactory.build(:transaction)
      block = TestFactory.build(:block, transactions: [transaction])
      receipt = TestFactory.build(:receipt, logs: [TestFactory.build(:log_entry)])

      response_receipt = Receipt.new(receipt, transaction, block)

      assert response_receipt == %JSONRPC2.Response.Receipt.ByzantiumReceipt{
               blockHash: "0x0000000000000000000000000000000000000000000000000000000000000010",
               blockNumber: "0x01",
               contractAddress: "0x2e07fda729826779d050aa629355211735ce350d",
               cumulativeGasUsed: "0x03e8",
               from: "0x619f56e8bed07fe196c0dbc41b52e2bc64817b3a",
               gasUsed: "0x03e8",
               logs: [
                 %{
                   address: "0x0000000000000000000000000000000000000010",
                   blockHash:
                     "0x0000000000000000000000000000000000000000000000000000000000000010",
                   blockNumber: "0x01",
                   data: "0x01",
                   logIndex: "0x00",
                   removed: false,
                   topics: [
                     "0x0000000000000000000000000000000000000000000000000000000000000000",
                     "0x0000000000000000000000000000000000000000000000000000000000000000",
                     "0x0000000000000000000000000000000000000000000000000000000000000000",
                     "0x0000000000000000000000000000000000000000000000000000000000000000"
                   ],
                   transactionHash:
                     "0x307837663731643134633133633430326365313363366630363362383365303835663039376138373865333331363364363134366365636532373739333635333162",
                   transactionIndex: "0x00"
                 }
               ],
               logsBloom:
                 "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
               status: "0x01",
               to: "0x",
               transactionHash:
                 "0x7f71d14c13c402ce13c6f063b83e085f097a878e33163d6146cece277936531b",
               transactionIndex: "0x00"
             }
    end

    test "creates response receipt from internal block for message call transaction" do
      transaction = TestFactory.build(:transaction, to: <<0x100::160>>, data: "contract creation")
      block = TestFactory.build(:block, transactions: [transaction])
      receipt = TestFactory.build(:receipt)

      response_receipt = Receipt.new(receipt, transaction, block)

      assert response_receipt == %JSONRPC2.Response.Receipt.ByzantiumReceipt{
               blockHash: "0x0000000000000000000000000000000000000000000000000000000000000010",
               blockNumber: "0x01",
               contractAddress: nil,
               cumulativeGasUsed: "0x03e8",
               from: "0xf029c9a86c67aa8c77424e3f278b36eaa3754a20",
               gasUsed: "0x03e8",
               logs: [],
               logsBloom:
                 "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
               status: "0x01",
               to: "0x0000000000000000000000000000000000000100",
               transactionHash:
                 "0xb33cd4e38a774e1abcef0d18e357140c5a55717d74b9349c119da6608a5c21e2",
               transactionIndex: "0x00"
             }
    end

    test "created pre-Byzantium receipt if state field is a root hash" do
      transaction = TestFactory.build(:transaction, to: <<0x100::160>>, data: "contract creation")
      block = TestFactory.build(:block, transactions: [transaction])
      receipt = TestFactory.build(:receipt, state: <<1, 5, 7>>)

      response_receipt = Receipt.new(receipt, transaction, block)

      assert response_receipt == %JSONRPC2.Response.Receipt.PreByzantiumReceipt{
               blockHash: "0x0000000000000000000000000000000000000000000000000000000000000010",
               blockNumber: "0x01",
               contractAddress: nil,
               cumulativeGasUsed: "0x03e8",
               from: "0xf029c9a86c67aa8c77424e3f278b36eaa3754a20",
               gasUsed: "0x03e8",
               logs: [],
               logsBloom:
                 "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
               root: "0x010507",
               to: "0x0000000000000000000000000000000000000100",
               transactionHash:
                 "0xb33cd4e38a774e1abcef0d18e357140c5a55717d74b9349c119da6608a5c21e2",
               transactionIndex: "0x00"
             }
    end

    test "correctly sets log numbers to receipt logs" do
      transaction1 = TestFactory.build(:transaction, gas_limit: 99)
      transaction2 = TestFactory.build(:transaction, gas_limit: 100)

      transactions = [transaction1, transaction2]

      receipt1 =
        TestFactory.build(:receipt,
          logs: [TestFactory.build(:log_entry), TestFactory.build(:log_entry)]
        )

      receipt2 =
        TestFactory.build(:receipt,
          logs: [TestFactory.build(:log_entry), TestFactory.build(:log_entry)]
        )

      receipts = [receipt1, receipt2]

      block = TestFactory.build(:block, receipts: receipts, transactions: transactions)

      response_receipt = Receipt.new(receipt2, transaction2, block)

      logs = response_receipt.logs

      assert Enum.count(logs) == 2
      assert Enum.at(logs, 0).logIndex == "0x02"
      assert Enum.at(logs, 1).logIndex == "0x03"
    end

    test "correctly encodes to json" do
      transaction = TestFactory.build(:transaction, to: <<0x100::160>>, data: "contract creation")
      block = TestFactory.build(:block, transactions: [transaction])
      receipt = TestFactory.build(:receipt, logs: [TestFactory.build(:log_entry)])

      json_receipt =
        receipt
        |> Receipt.new(transaction, block)
        |> Jason.encode!()

      assert json_receipt ==
               "{\"blockHash\":\"0x0000000000000000000000000000000000000000000000000000000000000010\",\"blockNumber\":\"0x01\",\"contractAddress\":null,\"cumulativeGasUsed\":\"0x03e8\",\"from\":\"0xf029c9a86c67aa8c77424e3f278b36eaa3754a20\",\"gasUsed\":\"0x03e8\",\"logs\":[{\"address\":\"0x0000000000000000000000000000000000000010\",\"blockHash\":\"0x0000000000000000000000000000000000000000000000000000000000000010\",\"blockNumber\":\"0x01\",\"data\":\"0x01\",\"logIndex\":\"0x00\",\"removed\":false,\"topics\":[\"0x0000000000000000000000000000000000000000000000000000000000000000\",\"0x0000000000000000000000000000000000000000000000000000000000000000\",\"0x0000000000000000000000000000000000000000000000000000000000000000\",\"0x0000000000000000000000000000000000000000000000000000000000000000\"],\"transactionHash\":\"0x307862333363643465333861373734653161626365663064313865333537313430633561353537313764373462393334396331313964613636303861356332316532\",\"transactionIndex\":\"0x00\"}],\"logsBloom\":\"0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000\",\"status\":\"0x01\",\"to\":\"0x0000000000000000000000000000000000000100\",\"transactionHash\":\"0xb33cd4e38a774e1abcef0d18e357140c5a55717d74b9349c119da6608a5c21e2\",\"transactionIndex\":\"0x00\"}"
    end
  end
end
