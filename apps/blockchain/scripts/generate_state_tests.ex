defmodule GenerateStateTests do
  alias MerklePatriciaTree.Trie
  alias Blockchain.{Account, Transaction}
  alias Blockchain.Interface.AccountInterface
  alias Blockchain.Account.Storage

  use EthCommonTest.Harness

  @base_path Path.join([EthCommonTest.Helpers.ethereum_common_tests_path(), "GeneralStateTests"])

  def run(args) do
    only_count = Enum.member?(args, "--count")
    test_counts = :ets.new(:test_counts, [:public])

    Enum.each(test_directories(), fn directory_path ->
      directory_path
      |> tests()
      |> Enum.each(fn test_path ->
        test_path
        |> read_state_test_file()
        |> Enum.each(fn test ->
          run_tests_in_json(test, test_path, test_counts, only_count)
        end)
      end)
    end)

    if only_count do
      [{"passing", passing_tests}] = :ets.lookup(test_counts, "passing")
      [{"failing", failing_tests}] = :ets.lookup(test_counts, "failing")
      [{"post_frontier", post_frontier_tests}] = :ets.lookup(test_counts, "post_frontier")
      total_tests = passing_tests + failing_tests

      log_test_percentage("Passing", passing_tests, total_tests)
      log_test_percentage("Failing", failing_tests, total_tests)
      IO.puts("Post Frontier tests: #{post_frontier_tests}")
    end
  end

  defp test_directories do
    path = Path.join([EthCommonTest.Helpers.ethereum_common_tests_path(), "GeneralStateTests"])
    wildcard = path <> "/*"

    wildcard
    |> Path.wildcard()
    |> Enum.sort()
  end

  defp tests(directory_path) do
    wildcard = directory_path <> "/**/*.json"

    wildcard
    |> Path.wildcard()
    |> Enum.sort()
  end

  defp run_tests_in_json(test, test_path, test_counts, only_count) do
    test_path = String.trim(test_path, @base_path <> "/")

    try do
      if Map.has_key?(test["post"], "Frontier") do
        all_posts_match =
          test["post"]["Frontier"]
          |> Enum.with_index()
          |> Enum.all?(fn indexed_post ->
            run_test(test, indexed_post)
          end)

        if all_posts_match do
          if !only_count, do: log_test(test_path)
          :ets.update_counter(test_counts, "passing", {2, 1}, {"passing", 0})
        else
          :ets.update_counter(test_counts, "failing", {2, 1}, {"failing", 0})
          if !only_count, do: log_commented_test(test_path)
        end
      else
        :ets.update_counter(test_counts, "post_frontier", {2, 1}, {"post_frontier", 0})
        if !only_count, do: log_test(test_path)
      end
    rescue
      _ ->
        :ets.update_counter(test_counts, "failing", {2, 1}, {"failing", 0})
        if !only_count, do: log_commented_test(test_path)
    end
  end

  defp run_test(test, {post, index}) do
    state = account_interface(test).state

    indexes = post["indexes"]
    gas_limit_index = indexes["gas"]
    value_index = indexes["value"]
    data_index = indexes["data"]

    transaction =
      %Transaction{
        nonce: load_integer(test["transaction"]["nonce"]),
        gas_price: load_integer(test["transaction"]["gasPrice"]),
        gas_limit: load_integer(Enum.at(test["transaction"]["gasLimit"], gas_limit_index)),
        data: maybe_hex(Enum.at(test["transaction"]["data"], data_index)),
        to: maybe_hex(test["transaction"]["to"]),
        value: load_integer(Enum.at(test["transaction"]["value"], value_index))
      }
      |> Transaction.Signature.sign_transaction(maybe_hex(test["transaction"]["secretKey"]))

    {state, _, _} =
      Transaction.execute(state, transaction, %Block.Header{
        beneficiary: maybe_hex(test["env"]["currentCoinbase"]),
        difficulty: load_integer(test["env"]["currentDifficulty"]),
        timestamp: load_integer(test["env"]["currentTimestamp"]),
        number: load_integer(test["env"]["currentNumber"]),
        gas_limit: load_integer(test["env"]["currentGasLimit"]),
        parent_hash: maybe_hex(test["env"]["previousHash"])
      })

    expected_hash =
      test["post"]["Frontier"]
      |> Enum.at(index)
      |> Map.fetch!("hash")
      |> maybe_hex()

    state.root_hash == expected_hash
  end

  defp log_test_percentage(test_type, test_count, total_tests) do
    IO.puts(
      "#{test_type} tests: #{test_count}/#{total_tests} = #{
        trunc(Float.round(test_count / total_tests, 2) * 100)
      }%"
    )
  end

  defp log_commented_test(test_name) do
    IO.puts("    # \"#{test_name}\",")
  end

  defp log_test(test_name) do
    IO.puts("      \"#{test_name}\",")
  end

  def read_state_test_file(test_path) do
    test_path
    |> File.read!()
    |> Poison.decode!()
    |> Enum.map(fn {_name, body} -> body end)
  end

  def account_interface(test) do
    db = MerklePatriciaTree.Test.random_ets_db()

    state = %Trie{
      db: db,
      root_hash: maybe_hex(test["env"]["previousHash"])
    }

    state =
      Enum.reduce(test["pre"], state, fn {address, account}, state ->
        storage = %Trie{
          root_hash: Trie.empty_trie_root_hash(),
          db: db
        }

        storage =
          Enum.reduce(account["storage"], storage, fn {key, value}, trie ->
            value = load_integer(value)

            if value == 0 do
              trie
            else
              Storage.put(trie.db, trie.root_hash, load_integer(key), value)
            end
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

    AccountInterface.new(state)
  end
end

GenerateStateTests.run(System.argv())
