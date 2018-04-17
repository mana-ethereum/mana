defmodule Block.HeaderTest do
  use ExUnit.Case, async: true
  doctest Block.Header
  alias Block.Header

  test "serialize and deserialize" do
    header = %Header{
      parent_hash: <<1::256>>,
      ommers_hash: <<2::256>>,
      beneficiary: <<3::160>>,
      state_root: <<4::256>>,
      transactions_root: <<5::256>>,
      receipts_root: <<6::256>>,
      logs_bloom: <<>>,
      difficulty: 5,
      number: 1,
      gas_limit: 5,
      gas_used: 3,
      timestamp: 6,
      extra_data: "Hi mom",
      mix_hash: <<7::256>>,
      nonce: <<8::64>>
    }

    assert header ==
             header |> Header.serialize() |> ExRLP.encode() |> ExRLP.decode()
             |> Header.deserialize()
  end
end
