defmodule GenerateBlockchainTests do
  use EthCommonTest.Harness

  alias Blockchain.{Blocktree, Account, Transaction, Chain}
  alias MerklePatriciaTree.Trie
  alias Blockchain.Account.Storage
  alias Block.Header

  @base_path System.cwd() <> "/../../ethereum_common_tests/BlockchainTests/"
  @allowed_forks ["Byzantium", "Frontier", "Homestead", "EIP150", "EIP158"]
  @byzantium_failing_tests_path System.cwd() <> "/test/support/byzantium_failing_tests.txt"

  def run(args) do
    hardfork = ensure_hardfork(args)
    io_device = io_device_from_hardfork(hardfork)

    {passing_count, failing_count} =
      Enum.reduce(
        tests(),
        {0, 0},
        fn json_test_path, {pass_acc, fail_acc} ->
          relative_path = String.trim(json_test_path, @base_path)

          {passing, failing} =
            json_test_path
            |> read_test()
            |> Enum.filter(fn {_name, test} ->
              test["network"] == hardfork
            end)
            |> Enum.reduce({0, 0}, fn {_name, test}, {pass_count, fail_count} ->
              try do
                run_test(test)
                {pass_count + 1, fail_count}
              rescue
                _ ->
                  {pass_count, fail_count + 1}
              end
            end)

          if failing != 0 do
            log_test(io_device, relative_path)
          end

          {pass_acc + passing, fail_acc + failing}
        end
      )

    all_tests = passing_count + failing_count

    IO.puts(
      "Passing #{hardfork} tests: #{passing_count}/#{all_tests} = #{
        round(passing_count / all_tests * 1000) / 10
      }%"
    )

    IO.puts(
      "Failing #{hardfork} tests: #{failing_count}/#{all_tests} = #{
        trunc(Float.round(failing_count / all_tests, 2) * 100)
      }%"
    )

    close_io_device(io_device)
  end

  defp close_io_device(:stdio), do: :ok
  defp close_io_device(file_pid), do: File.close(file_pid)

  defp io_device_from_hardfork(hardfork) do
    case hardfork do
      "Byzantium" ->
        File.open!(@byzantium_failing_tests_path, [:write])

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

  defp tests do
    wildcard = @base_path <> "**/*.json"

    wildcard
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

    chain = load_chain(json_test["network"])

    blocktree =
      create_blocktree()
      |> add_genesis_block(json_test, state, chain)
      |> add_blocks(json_test, state, chain)

    best_block_hash = maybe_hex(json_test["lastblockhash"])

    if blocktree.best_block.block_hash != best_block_hash, do: raise(RuntimeError)
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
end

GenerateBlockchainTests.run(System.argv())
