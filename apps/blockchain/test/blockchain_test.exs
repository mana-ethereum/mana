defmodule BlockchainTest do
  use ExUnit.Case

  import EthCommonTest.Helpers

  alias Blockchain.{Blocktree, Account, Transaction, Chain}
  alias MerklePatriciaTree.Trie
  alias Blockchain.Account.Storage
  alias Block.Header

  doctest Blockchain

  @failing_byzantium_tests File.read!(System.cwd() <> "/test/support/byzantium_failing_tests.txt")

  @failing_tests %{
    "Frontier" => [],
    "Homestead" => [],
    "EIP150" => [],
    "EIP158" => [
      "GeneralStateTests/stSpecialTest/failed_tx_xcf416c53_d0g0v0.json"
    ],
    "Byzantium" => String.split(@failing_byzantium_tests, "\n"),
    "Constantinople" => [
      "GeneralStateTests/stCreateTest/CreateOOGafterInitCodeReturndata_d0g1v0.json",
      "GeneralStateTests/stReturnDataTest/modexp_modsize0_returndatasize_d0g1v0.json",
      "GeneralStateTests/stReturnDataTest/modexp_modsize0_returndatasize_d0g2v0.json",
      "GeneralStateTests/stReturnDataTest/modexp_modsize0_returndatasize_d0g3v0.json",
      "GeneralStateTests/stShift/sar00_d0g0v0.json",
      "GeneralStateTests/stShift/sar01_d0g0v0.json",
      "GeneralStateTests/stShift/sar10_d0g0v0.json",
      "GeneralStateTests/stShift/sar11_d0g0v0.json",
      "GeneralStateTests/stShift/sar_0_256-1_d0g0v0.json",
      "GeneralStateTests/stShift/sar_2^254_254_d0g0v0.json",
      "GeneralStateTests/stShift/sar_2^255-1_248_d0g0v0.json",
      "GeneralStateTests/stShift/sar_2^255-1_254_d0g0v0.json",
      "GeneralStateTests/stShift/sar_2^255-1_255_d0g0v0.json",
      "GeneralStateTests/stShift/sar_2^255-1_256_d0g0v0.json",
      "GeneralStateTests/stShift/sar_2^255_1_d0g0v0.json",
      "GeneralStateTests/stShift/sar_2^255_255_d0g0v0.json",
      "GeneralStateTests/stShift/sar_2^255_256_d0g0v0.json",
      "GeneralStateTests/stShift/sar_2^255_257_d0g0v0.json",
      "GeneralStateTests/stShift/sar_2^256-1_0_d0g0v0.json",
      "GeneralStateTests/stShift/sar_2^256-1_1_d0g0v0.json",
      "GeneralStateTests/stShift/sar_2^256-1_255_d0g0v0.json",
      "GeneralStateTests/stShift/sar_2^256-1_256_d0g0v0.json",
      "GeneralStateTests/stShift/shl01-0100_d0g0v0.json",
      "GeneralStateTests/stShift/shl01-0101_d0g0v0.json",
      "GeneralStateTests/stShift/shl01-ff_d0g0v0.json",
      "GeneralStateTests/stShift/shl01_d0g0v0.json",
      "GeneralStateTests/stShift/shl10_d0g0v0.json",
      "GeneralStateTests/stShift/shl11_d0g0v0.json",
      "GeneralStateTests/stShift/shl7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff-01_d0g0v0.json",
      "GeneralStateTests/stShift/shlffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff-00_d0g0v0.json",
      "GeneralStateTests/stShift/shlffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff-0100_d0g0v0.json",
      "GeneralStateTests/stShift/shlffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff-01_d0g0v0.json",
      "GeneralStateTests/stShift/shlffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff-ff_d0g0v0.json",
      "GeneralStateTests/stShift/shr01_d0g0v0.json",
      "GeneralStateTests/stShift/shr10_d0g0v0.json",
      "GeneralStateTests/stShift/shr11_d0g0v0.json",
      "GeneralStateTests/stShift/shr_-1_0_d0g0v0.json",
      "GeneralStateTests/stShift/shr_-1_1_d0g0v0.json",
      "GeneralStateTests/stShift/shr_-1_255_d0g0v0.json",
      "GeneralStateTests/stShift/shr_-1_256_d0g0v0.json",
      "GeneralStateTests/stShift/shr_2^255_1_d0g0v0.json",
      "GeneralStateTests/stShift/shr_2^255_255_d0g0v0.json",
      "GeneralStateTests/stShift/shr_2^255_256_d0g0v0.json",
      "GeneralStateTests/stShift/shr_2^255_257_d0g0v0.json",
      "bcStateTests/blockhashNonConstArg.json"
    ],
    # the rest are not implemented yet
    "EIP158ToByzantiumAt5" => [],
    "FrontierToHomesteadAt5" => [],
    "HomesteadToDaoAt5" => [],
    "HomesteadToEIP150At5" => []
  }

  @ten_minutes 1000 * 60 * 10
  @num_test_groups 10

  @tag :ethereum_common_tests
  @tag :blockchain_common_tests
  test "runs blockchain tests" do
    grouped_test_per_fork()
    |> Task.async_stream(&run_tests(&1), timeout: @ten_minutes)
    |> Enum.flat_map(fn {:ok, results} -> results end)
    |> make_assertions()
  end

  defp grouped_test_per_fork do
    for fork <- forks_with_existing_implementation(),
        test_group <- split_tests_into_groups(@num_test_groups),
        do: {fork, test_group}
  end

  defp split_tests_into_groups(num_groups_desired) do
    all_tests = tests()
    test_count = Enum.count(all_tests)
    tests_per_group = div(test_count, num_groups_desired)

    Enum.chunk_every(all_tests, tests_per_group)
  end

  defp run_tests({fork, tests}) do
    tests
    |> Stream.reject(&known_fork_failures?(&1, fork))
    |> Enum.flat_map(fn json_test_path ->
      json_test_path
      |> read_test()
      |> Stream.filter(&fork_test?(&1, fork))
      |> Stream.map(&run_test/1)
      |> Enum.filter(&failing_test?/1)
    end)
  end

  defp known_fork_failures?(json_test_path, fork) do
    hardfork_failing_tests = Map.fetch!(@failing_tests, fork)

    Enum.any?(hardfork_failing_tests, fn failing_test ->
      String.contains?(json_test_path, failing_test)
    end)
  end

  defp read_test(path) do
    path
    |> File.read!()
    |> Poison.decode!()
  end

  defp fork_test?({_test_name, json_test}, fork) do
    fork == json_test["network"]
  end

  defp forks_with_existing_implementation do
    @failing_tests
    |> Map.keys()
    |> Enum.reject(&fork_without_implementation?/1)
  end

  defp fork_without_implementation?(fork) do
    fork
    |> load_chain()
    |> is_nil()
  end

  defp run_test({test_name, json_test}) do
    fork = json_test["network"]
    chain = load_chain(fork)

    state = populate_prestate(json_test)

    blocktree =
      create_blocktree()
      |> add_genesis_block(json_test, state, chain)
      |> add_blocks(json_test, state, chain)

    best_block_hash = maybe_hex(json_test["lastblockhash"])

    {fork, test_name, best_block_hash, blocktree.best_block.block_hash}
  end

  defp make_assertions([]), do: assert(true)
  defp make_assertions(failing_tests), do: refute(true, failure_message(failing_tests))

  defp failure_message(failing_tests) do
    total_failures = Enum.count(failing_tests)

    error_messages =
      failing_tests
      |> Enum.map(&single_error_message/1)
      |> Enum.join("\n")

    """
    Block hash mismatch for the following tests:
    #{error_messages}
    -----------------
    Total failures: #{inspect(total_failures)}
    """
  end

  defp single_error_message({fork, test_name, expected, actual}) do
    "[#{fork}] #{test_name}: expected #{inspect(expected)}, but received #{inspect(actual)}"
  end

  defp failing_test?({_fork, _test_name, expected, actual}) do
    expected != actual
  end

  defp load_chain(hardfork) do
    config = evm_config(hardfork)

    case hardfork do
      "Frontier" ->
        Chain.load_chain(:frontier_test, config)

      "Homestead" ->
        Chain.load_chain(:homestead_test, config)

      "EIP150" ->
        Chain.load_chain(:eip150_test, config)

      "EIP158" ->
        Chain.load_chain(:eip150_test, config)

      "Byzantium" ->
        Chain.load_chain(:byzantium_test, config)

      "Constantinople" ->
        Chain.load_chain(:constantinople_test, config)

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

      "EIP150" ->
        EVM.Configuration.EIP150.new()

      "EIP158" ->
        EVM.Configuration.EIP158.new()

      "Byzantium" ->
        EVM.Configuration.Byzantium.new()

      "Constantinople" ->
        EVM.Configuration.Constantinople.new()

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
    ethereum_common_tests_path()
    |> Path.join("/BlockchainTests/**/*.json")
    |> Path.wildcard()
    |> Enum.sort()
  end
end
