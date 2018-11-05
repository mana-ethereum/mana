defmodule GenerateBlockchainTests do
  use EthCommonTest.Harness

  alias Block.Header
  alias Blockchain.{Account, Blocktree, Chain, Transaction}
  alias Blockchain.Account.Storage
  alias MerklePatriciaTree.Trie
  import EthCommonTest.Helpers

  @base_path System.cwd() <> "/../../ethereum_common_tests/BlockchainTests/"
  @allowed_forks [
    "Constantinople",
    "Byzantium",
    "Frontier",
    "Homestead",
    "HomesteadToDaoAt5",
    "TangerineWhistle",
    "SpuriousDragon"
  ]
  @constantinople_failing_tests_path System.cwd() <>
                                       "/test/support/constantinople_failing_tests.txt"
  @initial_pass_fail {[], []}
  @number_of_test_groups 20
  @ten_minutes 1000 * 60 * 10

  def run(args) do
    hardfork = ensure_hardfork(args)
    io_device = io_device_from_hardfork(hardfork)

    {passing_tests, failing_tests} =
      tests_files()
      |> split_into_groups(@number_of_test_groups)
      |> Task.async_stream(&run_test_group(&1, hardfork), timeout: @ten_minutes)
      |> Enum.reduce(@initial_pass_fail, fn {:ok, {passing, failing}}, {pass_acc, fail_acc} ->
        {passing ++ pass_acc, failing ++ fail_acc}
      end)

    failing_tests
    |> Enum.sort()
    |> Enum.each(&log_test(io_device, &1))

    passing_count = length(passing_tests)
    failing_count = length(failing_tests)
    all_tests = passing_count + failing_count

    log_passing_count(hardfork, passing_count, all_tests)
    log_failing_count(hardfork, failing_count, all_tests)

    close_io_device(io_device)
  end

  defp log_passing_count(hardfork, passing_count, all_tests) do
    IO.puts(
      "Passing #{hardfork} tests: #{passing_count}/#{all_tests} = #{
        round(passing_count / all_tests * 1000) / 10
      }%"
    )
  end

  defp log_failing_count(hardfork, failing_count, all_tests) do
    IO.puts(
      "Failing #{hardfork} tests: #{failing_count}/#{all_tests} = #{
        trunc(Float.round(failing_count / all_tests, 2) * 100)
      }%"
    )
  end

  defp run_test_group(test_group, hardfork) do
    Enum.reduce(test_group, @initial_pass_fail, &run_tests_in_file(&1, &2, hardfork))
  end

  defp run_tests_in_file(json_test_path, {pass_acc, fail_acc}, hardfork) do
    relative_path = String.trim(json_test_path, @base_path)

    {passing, failing} =
      json_test_path
      |> read_test()
      |> Enum.filter(&fork_test?(&1, hardfork))
      |> Enum.reduce(@initial_pass_fail, &pass_or_fail(&1, &2, relative_path))

    {pass_acc ++ passing, fail_acc ++ failing}
  end

  defp split_into_groups(all_tests, num_groups_desired) do
    test_count = Enum.count(all_tests)
    tests_per_group = div(test_count, num_groups_desired)

    Enum.chunk_every(all_tests, tests_per_group)
  end

  defp pass_or_fail({_name, test}, {passing, failing}, relative_path) do
    case run_test(test) do
      :pass ->
        {[relative_path | passing], failing}

      :fail ->
        {passing, [relative_path | failing]}
    end
  end

  defp fork_test?({_name, test_data}, hardfork) do
    human_readable_fork_name(test_data["network"]) == hardfork
  end

  defp close_io_device(:stdio), do: :ok
  defp close_io_device(file_pid), do: File.close(file_pid)

  defp io_device_from_hardfork(hardfork) do
    case hardfork do
      "Constantinople" ->
        File.open!(@constantinople_failing_tests_path, [:write])

      _ ->
        :stdio
    end
  end

  defp ensure_hardfork(args) do
    hardfork = List.first(args)

    if !Enum.member?(@allowed_forks, hardfork),
      do: raise("Please specify a fork: #{inspect(@allowed_forks)}")

    hardfork
  end

  defp tests_files do
    @base_path
    |> Path.join("**/*.json")
    |> Path.wildcard()
    |> Enum.sort()
  end

  defp log_test(:stdio, path), do: IO.puts("      \"#{path}\",")
  defp log_test(file_pid, path), do: IO.write(file_pid, "#{path}\n")

  defp read_test(path) do
    path
    |> File.read!()
    |> Poison.decode!()
  end

  defp run_test(json_test) do
    state = populate_prestate(json_test)

    chain = load_chain(human_readable_fork_name(json_test["network"]))

    blocktree =
      create_blocktree()
      |> add_genesis_block(json_test, state, chain)
      |> add_blocks(json_test, state, chain)

    best_block_hash = maybe_hex(json_test["lastblockhash"])

    if blocktree.best_block.block_hash == best_block_hash, do: :pass, else: :fail
  end

  defp load_chain(hardfork) do
    Chain.test_config(hardfork)
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

  defp ommers_from_json(nil), do: :ok
  defp ommers_from_json(json_ommers) do
    Enum.map(json_ommers, fn json_ommer ->
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

  defp transactions_from_json(nil), do: :ok
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
end

GenerateBlockchainTests.run(System.argv())
