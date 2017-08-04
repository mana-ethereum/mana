defmodule Blockchain.Transaction.ReceiptTest do
  use ExUnit.Case, async: true
  doctest Blockchain.Transaction.Receipt
  alias Blockchain.Transaction.Receipt

  test "serilalize and deserialize" do
    receipt = %Receipt{state: <<1,2,3>>, cumulative_gas: 5, bloom_filter: <<2,3,4>>, logs: "hi mom"}

    assert receipt == receipt |> Receipt.serialize |> ExRLP.encode |> ExRLP.decode |> Receipt.deserialize
  end
end