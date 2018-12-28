defmodule JSONRPC2.SpecHandler.GasEstimaterTest do
  use ExUnit.Case, async: true

  alias Blockchain.Account
  alias Blockchain.Block
  alias Blockchain.Chain
  alias JSONRPC2.SpecHandler.GasEstimater
  alias JSONRPC2.TestFactory

  setup do
    db = MerklePatriciaTree.Test.random_ets_db()
    trie = MerklePatriciaTree.Trie.new(db)
    chain = Chain.load_chain(:ropsten)

    {:ok, %{trie: trie, chain: chain}}
  end

  describe "run/4" do
    test "can't find block by block number", %{trie: trie, chain: chain} do
      call_request = TestFactory.build(:call_request)

      result = GasEstimater.run(trie, call_request, 10, chain)

      assert result == {:error, "Block is not found"}
    end

    test "returns lower gas limit", %{trie: trie, chain: chain} do
      block =
        TestFactory.build(:block, header: TestFactory.build(:header, gas_limit: 100_000_000))

      from_address = <<0x10::160>>
      from_account = TestFactory.build(:account, balance: 10_000_000)

      to_address = <<0x11::160>>
      to_account = TestFactory.build(:account)

      {:ok, {_, updated_trie}} = Block.put_block(block, trie, block.block_hash)

      call_request =
        TestFactory.build(:call_request, from: from_address, to: to_address, gas: 30_000)

      trie_with_accounts =
        updated_trie
        |> Account.put_account(from_address, from_account)
        |> Account.put_account(to_address, to_account)

      result = GasEstimater.run(trie_with_accounts, call_request, block.header.number, chain)

      assert result == {:ok, 21_000}
    end
  end
end
