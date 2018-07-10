defmodule BlockchainTest do
  use ExUnit.Case
  use EthCommonTest.Harness

  alias Blockchain.{Blocktree, Account, Transaction}
  alias MerklePatriciaTree.Trie
  alias Blockchain.Account.Storage
  alias Block.Header

  doctest Blockchain

  @ethereum_common_tests_path "/../../ethereum_common_tests/BlockchainTests/"
  @test "/GeneralStateTests/stSystemOperationsTest/ABAcalls0_d0g0v0"

  test "runs blockchain common tests" do
    @test
    |> read_test()
    |> run_test()
  end

  defp read_test(relative_path) do
    path = System.cwd() <> @ethereum_common_tests_path <> relative_path <> ".json"

    path
    |> File.read!()
    |> Poison.decode!()
    |> Map.fetch!("ABAcalls0_d0g0v0_Frontier")
  end

  defp run_test(json_test) do
    state = populate_prestate(json_test)
    chain = Blockchain.Chain.load_chain(:frontier_test)

    blocktree =
      create_blocktree()
      |> add_genesis_block(json_test, state, chain)
      |> add_blocks(json_test, state, chain)

    canonical_block = Blocktree.get_canonical_block(blocktree)
    best_block_hash = maybe_hex(json_test["lastblockhash"])

    assert canonical_block.block_hash == best_block_hash
  end

  defp add_genesis_block(blocktree, json_test, state, chain) do
    genesis_block = block_from_json(json_test["genesisRLP"], json_test["genesisBlockHeader"])

    {:ok, blocktree} =
      Blocktree.verify_and_add_block(blocktree, chain, genesis_block, state.db, false)

    blocktree
  end

  defp create_blocktree do
    Blocktree.new_tree()
  end

  defp add_blocks(blocktree, json_test, state, chain) do
    Enum.reduce(json_test["blocks"], blocktree, fn json_block, acc ->
      block =
        block_from_json(json_block["rlp"], json_block["blockHeader"], json_block["transactions"])

      {:ok, blocktree} = Blocktree.verify_and_add_block(acc, chain, block, state.db)

      blocktree
    end)
  end

  defp block_from_json(rlp, json_header, json_transactions \\ [], json_ommers \\ []) do
    block = block_from_rlp(rlp)
    header = header_from_json(json_header)
    transactions = transactions_from_json(json_transactions)

    %{block | header: header, transactions: transactions, ommers: []}
  end

  defp block_from_rlp(block_rlp) do
    block_rlp
    |> maybe_hex()
    |> ExRLP.decode()
    |> Blockchain.Block.deserialize()
  end

  defp header_from_json(json_header) do
    %Header{
      parent_hash: maybe_hex(json_header["parentHash"]),
      ommers_hash: maybe_hex(json_header["uncleHash"]),
      beneficiary: maybe_hex(json_header["coinbase"]),
      state_root: maybe_hex(json_header["stateRoot"]),
      transactions_root: maybe_hex(json_header["transactionsTrie"]),
      receipts_root: maybe_hex(json_header["receiptTrie"]),
      logs_bloom: maybe_hex(json_header["bloom"]),
      difficulty: load_integer(json_header["difficulty"]),
      number: load_integer(json_header["number"]),
      gas_limit: load_integer(json_header["gasLimit"]),
      gas_used: load_integer(json_header["gasUsed"]),
      timestamp: load_integer(json_header["timestamp"]),
      extra_data: maybe_hex(json_header["extraData"]),
      mix_hash: maybe_hex(json_header["mixHash"]),
      nonce: maybe_hex(json_header["nonce"])
    }
  end

  defp transactions_from_json(json_transactions) do
    Enum.reduce(json_transactions, [], fn json_transaction, acc ->
      transaction = %Transaction{
        nonce: load_integer(json_transaction["nonce"]),
        gas_price: load_integer(json_transaction["gasPrice"]),
        gas_limit: load_integer(json_transaction["gasLimit"]),
        to: maybe_hex(json_transaction["to"]),
        value: load_integer(json_transaction["value"]),
        v: load_integer(json_transaction["v"]),
        r: load_integer(json_transaction["r"]),
        s: load_integer(json_transaction["s"]),
        data: maybe_hex(json_transaction["data"])
      }

      acc ++ [transaction]
    end)
  end

  defp populate_prestate(json_test) do
    db = MerklePatriciaTree.Test.random_ets_db()

    state = %Trie{
      db: db,
      root_hash: maybe_hex(json_test["genesisBlockHeader"]["stateRoot"])
    }

    Enum.reduce(json_test["pre"], state, fn {address, account}, state ->
      storage = %Trie{
        root_hash: Trie.empty_trie_root_hash(),
        db: db
      }

      storage =
        Enum.reduce(account["storage"], storage, fn {key, value}, trie ->
          Storage.put(trie.db, trie.root_hash, load_integer(key), load_integer(value))
        end)

      new_account = %Account{
        nonce: load_integer(account["nonce"]),
        balance: load_integer(account["balance"]),
        storage_root: storage.root_hash
      }

      state
      |> Account.put_account(maybe_hex(address), new_account)
      |> Account.put_code(maybe_hex(address), maybe_hex(account["code"]))
    end)
  end
end
