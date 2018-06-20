defmodule EthCore.Block.HeaderTest do
  use ExUnit.Case
  doctest EthCore.Block.Header

  alias EthCore.Block.Header

  describe "serialize/1" do
    test "serializes a block header" do
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

      expected = [
        <<1::256>>,
        <<2::256>>,
        <<3::160>>,
        <<4::256>>,
        <<5::256>>,
        <<6::256>>,
        <<>>,
        5,
        1,
        5,
        3,
        6,
        "Hi mom",
        <<7::256>>,
        <<8::64>>
      ]

      assert Header.serialize(header) == expected
    end
  end

  describe "deserialize/1" do
    test "deserializes an RLP-encoded block header" do
      rlp = [
        <<1::256>>,
        <<2::256>>,
        <<3::160>>,
        <<4::256>>,
        <<5::256>>,
        <<6::256>>,
        <<>>,
        <<5>>,
        <<1>>,
        <<5>>,
        <<3>>,
        <<6>>,
        "Hi mom",
        <<7::256>>,
        <<8::64>>
      ]

      expected = %Header{
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

      assert Header.deserialize(rlp) == expected
    end
  end

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

    roundtrip =
      header
      |> Header.serialize()
      |> ExRLP.encode()
      |> ExRLP.decode()
      |> Header.deserialize()

    assert header == roundtrip
  end

  describe "hash/1" do
    test "computes hash of a block header" do
      header = %Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}
      expected = <<78, 28, 127, 10, 192, 253, 127, 239, 254, 179, 39, 34, 245, 44, 152, 98, 128, 71, 238, 155, 100, 161, 199, 71, 243, 223, 172, 191, 74, 99, 128, 63>>

      assert Header.hash(header) == expected
    end
  end
end
