defmodule Blockchain.BlockTest do
  use ExUnit.Case, async: true
  doctest Blockchain.Block

  alias Block.Header
  alias Blockchain.Block
  alias Blockchain.Transaction

  require Integer

  @passing_tests %{
    basic_genesis_tests: [:test2, :test3]
  }

  test "Ethereum Common Tests" do
    for {test_type, test_group} <- @passing_tests do
      for {test_name, test} <- read_test_file(test_type),
        ( test_group == :all or Enum.member?(test_group, String.to_atom(test_name)) ) do

        db = MerklePatriciaTree.Test.random_ets_db()

        chain = %Blockchain.Chain{
          genesis: %{
            timestamp: test["timestamp"] |> maybe_hex,
            parent_hash: test["parentHash"] |> maybe_hex,
            extra_data: test["extraData"] |> maybe_hex,
            gas_limit: test["gasLimit"] |> maybe_hex,
            difficulty: test["difficulty"] |> maybe_hex,
            author: test["coinbase"] |> maybe_hex,
            mix_hash: test["mixhash"] |> maybe_hex,
            nonce: test["nonce"] |> maybe_hex,
          },
          accounts: get_test_accounts(test["alloc"])
        }

        block = Block.gen_genesis_block(chain, db)

        # Check that our block matches the serialization from common tests
        assert Block.serialize(block) == test["result"] |> maybe_hex |> ExRLP.decode
      end
    end
  end

  defp get_test_accounts(alloc) do
    for {k, v} <- alloc do
      {k |> load_raw_hex, %{
        balance: ( v["balance"] || v["wei"] || "0" ) |> load_decimal,
        storage: get_storage(v["storage"])
        }}
    end
  end

  defp get_storage(nil), do: %{}
  defp get_storage(storage) when is_map(storage) do
    for {k, v} <- storage do
      {k |> maybe_hex(:integer), v |> maybe_hex(:integer)}
    end |> Enum.into(%{})
  end

  test "serialize and deserialize a block is lossless" do
    block = %Block{
      header: %Header{parent_hash: <<1::256>>, ommers_hash: <<2::256>>, beneficiary: <<3::160>>, state_root: <<4::256>>, transactions_root: <<5::256>>, receipts_root: <<6::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<7::256>>, nonce: <<8::64>>},
      transactions: [%Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1::160>>, value: 8, v: 27, r: 9, s: 10, data: "hi"}],
      ommers: [%Header{parent_hash: <<11::256>>, ommers_hash: <<12::256>>, beneficiary: <<13::160>>, state_root: <<14::256>>, transactions_root: <<15::256>>, receipts_root: <<16::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<17::256>>, nonce: <<18::64>>}]
    }

    assert block == block |> Block.serialize |> ExRLP.encode |> ExRLP.decode |> Block.deserialize
  end

  test "match genesis block on ropsten" do
    db = MerklePatriciaTree.Test.random_ets_db()
    chain = Blockchain.Test.ropsten_chain()

    block = Blockchain.Block.gen_genesis_block(chain, db)
      |> Blockchain.Block.add_rewards_to_block(db)
      |> Blockchain.Block.put_header(:mix_hash, <<0::256>>)
      |> Blockchain.Block.put_header(:nonce, <<0x42::64>>)

    block = %{ block | block_hash: Block.hash(block) }

    assert block ==
      %Blockchain.Block{
        block_hash: <<65, 148, 16, 35, 104, 9, 35, 224, 254, 77, 116, 163, 75, 218, 200, 20, 31, 37, 64, 227, 174, 144, 98, 55, 24, 228, 125, 102, 209, 202, 74, 45>>,
        header: %Header{
          beneficiary: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
          difficulty: 1048576,
          extra_data: "55555555555555555555555555555555",
          gas_limit: 16777216,
          gas_used: 0,
          logs_bloom: <<0::2048>>,
          mix_hash: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
          nonce: <<0, 0, 0, 0, 0, 0, 0, 66>>,
          number: 0,
          ommers_hash: <<29, 204, 77, 232, 222, 199, 93, 122, 171, 133, 181, 103, 182, 204, 212, 26, 211, 18, 69, 27, 148, 138, 116, 19, 240, 161, 66, 253, 64, 212, 147, 71>>,
          parent_hash: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
          receipts_root: <<86, 232, 31, 23, 27, 204, 85, 166, 255, 131, 69, 230, 146, 192, 248, 110, 91, 72, 224, 27, 153, 108, 173, 192, 1, 98, 47, 181, 227, 99, 180, 33>>,
          state_root: <<33, 123, 11, 188, 251, 114, 226, 213, 126, 40, 243, 60, 179, 97, 185, 152, 53, 19, 23, 119, 85, 220, 63, 51, 206, 62, 112, 34, 237, 98, 183, 123>>,
          timestamp: 0,
          transactions_root: <<86, 232, 31, 23, 27, 204, 85, 166, 255, 131, 69, 230, 146, 192, 248, 110, 91, 72, 224, 27, 153, 108, 173, 192, 1, 98, 47, 181, 227, 99, 180, 33>>
        },
        ommers: [],
        transactions: []
      }
  end

  test "assert fully valid genesis block on ropsten" do
    db = MerklePatriciaTree.Test.random_ets_db()
    chain = Blockchain.Test.ropsten_chain()

    Blockchain.Block.gen_genesis_block(chain, db)
      |> Blockchain.Block.add_rewards_to_block(db)
      |> Blockchain.Block.is_fully_valid?(chain, nil, db)
  end

  # TODO: Do we want to standardize this test harness?
  defp read_test_file(type) do
    {:ok, body} = File.read(test_file_name(type))
    Poison.decode!(body)
  end

  defp test_file_name(type) do
    "test/support/ethereum_common_tests/GenesisTests/#{Atom.to_string(type)}.json"
  end

  # TODO: Do we want to standardize these de-serializers?
  @spec maybe_hex(String.t | nil) :: binary() | nil
  def maybe_hex(hex_data, type \\ :raw)
  def maybe_hex(nil, _), do: nil
  def maybe_hex(hex_data, :raw), do: load_raw_hex(hex_data)
  def maybe_hex(hex_data, :integer), do: load_hex(hex_data)

  def load_decimal(dec_data) do
    {res, ""} = Integer.parse(dec_data)

    res
  end

  @spec load_raw_hex(String.t) :: binary()
  defp load_raw_hex("0x" <> hex_data), do: load_raw_hex(hex_data)
  defp load_raw_hex(hex_data) when Integer.is_odd(byte_size(hex_data)), do: load_raw_hex("0" <> hex_data)
  defp load_raw_hex(hex_data) do
    Base.decode16!(hex_data, case: :mixed)
  end

  @spec load_hex(String.t) :: integer()
  defp load_hex(hex_data), do: hex_data |> load_raw_hex |> :binary.decode_unsigned

end