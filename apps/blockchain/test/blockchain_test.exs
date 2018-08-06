defmodule BlockchainTest do
  use ExUnit.Case
  use EthCommonTest.Harness

  alias Blockchain.{Blocktree, Account, Transaction, Chain}
  alias MerklePatriciaTree.Trie
  alias Blockchain.Account.Storage
  alias Block.Header

  doctest Blockchain

  @ethereum_common_tests_path System.cwd() <> "/../../ethereum_common_tests/BlockchainTests/"

  @failing_tests %{
    "Frontier" => [
      "GeneralStateTests/stMemoryTest/extcodecopy_dejavu_d0g0v0.json",
      "bcRandomBlockhashTest/randomStatetest21BC.json"
    ],
    "Homestead" => [
      "GeneralStateTests/stDelegatecallTestHomestead/delegatecodeDynamicCode_d0g0v0.json",
      "GeneralStateTests/stMemoryTest/extcodecopy_dejavu_d0g0v0.json",
      "GeneralStateTests/stRandom2/randomStatetest571_d0g0v0.json",
      "GeneralStateTests/stRandom2/randomStatetest643_d0g0v0.json",
      "bcRandomBlockhashTest/randomStatetest21BC.json",
      "bcValidBlockTest/dataTx2.json",
      "bcWalletTest/wallet2outOf3txs.json"
    ],
    # the rest are not implemented yet
    "Byzantium" => [],
    "EIP150" => [],
    "EIP158" => [],
    "Constantinople" => [],
    "EIP158ToByzantiumAt5" => [],
    "FrontierToHomesteadAt5" => [],
    "HomesteadToDaoAt5" => [],
    "HomesteadToEIP150At5" => []
  }

  test "runs blockchain tests" do
    Enum.each(tests(), fn json_test_path ->
      json_test_path
      |> read_test()
      |> Enum.map(fn {_name, test} -> test end)
      |> Enum.each(fn test ->
        if failing_test?(json_test_path, test) do
          run_test(test)
        end
      end)
    end)
  end

  defp failing_test?(json_test_path, json_test) do
    hardfork_failing_tests = Map.fetch!(@failing_tests, json_test["network"])

    Enum.any?(hardfork_failing_tests, fn failing_test ->
      String.contains?(json_test_path, failing_test)
    end)
  end

  defp read_test(path) do
    path
    |> File.read!()
    |> Poison.decode!()
  end

  defp run_test(json_test) do
    chain = load_chain(json_test["network"])

    if chain do
      state = populate_prestate(json_test)

      blocktree =
        create_blocktree()
        |> add_genesis_block(json_test, state, chain)
        |> add_blocks(json_test, state, chain)

      best_block_hash = maybe_hex(json_test["lastblockhash"])

      IO.puts("got #{inspect(blocktree.best_block.block_hash |> Base.encode16(case: :lower))}")

      IO.puts("expected #{inspect(best_block_hash |> Base.encode16(case: :lower))}")

      assert blocktree.best_block.block_hash == best_block_hash
    end
  end

  defp load_chain(hardfork) do
    config = evm_config(hardfork)

    case hardfork do
      "Frontier" ->
        Chain.load_chain(:frontier_test, config)

      "Homestead" ->
        Chain.load_chain(:homestead_test, config)

      _ ->
        nil
    end
  end

  defp evm_config(hardfork) do
    case hardfork do
      "Frontier" ->
        EVM.Configuration.Frontier.new()

      "Homestead" ->
        EVM.Configuration.Homestead.new()

      _ ->
        nil
    end
  end

  defp add_genesis_block(blocktree, json_test, state, chain) do
    block =
      if json_test["genesisRLP"] do
        {:ok, block} = Blockchain.Block.decode_rlp(json_test["genesisRLP"])

        block
      end

    genesis_block = block_from_json(block, json_test["genesisBlockHeader"])

    {:ok, blocktree} =
      Blocktree.verify_and_add_block(
        blocktree,
        chain,
        genesis_block,
        state.db,
        false,
        maybe_hex(json_test["genesisBlockHeader"]["hash"])
      )

    blocktree
  end

  defp create_blocktree do
    Blocktree.new_tree()
  end

  defp add_blocks(blocktree, json_test, state, chain) do
    Enum.reduce(json_test["blocks"], blocktree, fn json_block, acc ->
      block = json_block["rlp"] |> Blockchain.Block.decode_rlp()

      case block do
        {:ok, block} ->
          block =
            block_from_json(
              block,
              json_block["blockHeader"],
              json_block["transactions"],
              json_block["uncleHeaders"]
            )

          case Blocktree.verify_and_add_block(acc, chain, block, state.db) do
            {:ok, blocktree} -> blocktree
            _ -> acc
          end

        _ ->
          acc
      end
    end)
  end

  defp block_from_json(block, json_header, json_transactions \\ [], json_ommers \\ []) do
    block = block || %Blockchain.Block{}
    header = header_from_json(json_header)
    transactions = transactions_from_json(json_transactions)
    ommers = ommers_from_json(json_ommers)

    %{block | header: header, transactions: transactions, ommers: ommers}
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

  defp ommers_from_json(json_ommers) do
    Enum.map(json_ommers || [], fn json_ommer ->
      %Header{
        parent_hash: maybe_hex(json_ommer["parentHash"]),
        ommers_hash: maybe_hex(json_ommer["uncleHash"]),
        beneficiary: maybe_hex(json_ommer["coinbase"]),
        state_root: maybe_hex(json_ommer["stateRoot"]),
        transactions_root: maybe_hex(json_ommer["transactionsTrie"]),
        receipts_root: maybe_hex(json_ommer["receiptTrie"]),
        logs_bloom: maybe_hex(json_ommer["bloom"]),
        difficulty: load_integer(json_ommer["difficulty"]),
        number: load_integer(json_ommer["number"]),
        gas_limit: load_integer(json_ommer["gasLimit"]),
        gas_used: load_integer(json_ommer["gasUsed"]),
        timestamp: load_integer(json_ommer["timestamp"]),
        extra_data: maybe_hex(json_ommer["extraData"]),
        mix_hash: maybe_hex(json_ommer["mixHash"]),
        nonce: maybe_hex(json_ommer["nonce"])
      }
    end)
  end

  defp transactions_from_json(json_transactions) do
    Enum.map(json_transactions || [], fn json_transaction ->
      init =
        if maybe_hex(json_transaction["to"]) == <<>> do
          maybe_hex(json_transaction["data"])
        else
          ""
        end

      %Transaction{
        nonce: load_integer(json_transaction["nonce"]),
        gas_price: load_integer(json_transaction["gasPrice"]),
        gas_limit: load_integer(json_transaction["gasLimit"]),
        to: maybe_hex(json_transaction["to"]),
        value: load_integer(json_transaction["value"]),
        v: load_integer(json_transaction["v"]),
        r: load_integer(json_transaction["r"]),
        s: load_integer(json_transaction["s"]),
        data: maybe_hex(json_transaction["data"]),
        init: init
      }
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

  defp tests do
    # wildcard = @ethereum_common_tests_path <> "**/*.json"
    wildcard = @ethereum_common_tests_path <> "**/callcodecall_10_d0g0v0.json"

    wildcard
    |> Path.wildcard()
    |> Enum.sort()
  end
end
