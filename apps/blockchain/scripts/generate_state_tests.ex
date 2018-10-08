defmodule GenerateStateTests do
  alias MerklePatriciaTree.Trie
  alias Blockchain.Account
  alias Blockchain.Interface.AccountInterface
  alias Blockchain.Account.Storage
  alias EthCommonTest.StateTestRunner

  use EthCommonTest.Harness

  @hardforks [
    "EIP158",
    "EIP150",
    "Homestead",
    "Frontier",
    "Byzantium",
    "Constantinople"
  ]

  @twenty_minutes 60 * 20 * 1000
  @initial_state %{
    passing: %{
      "Homestead" => [],
      "Frontier" => [],
      "EIP150" => [],
      "EIP158" => [],
      "Byzantium" => [],
      "Constantinople" => []
    },
    failing: %{
      "Homestead" => [],
      "Frontier" => [],
      "EIP150" => [],
      "EIP158" => [],
      "Byzantium" => [],
      "Constantinople" => []
    }
  }

  def run(_args) do
    completed_tests =
      test_directories()
      |> Task.async_stream(&run_group_tests/1, timeout: @twenty_minutes)
      |> Enum.reduce(@initial_state, fn {:ok, result}, acc ->
        passing =
          Map.merge(acc[:passing], result[:passing], fn _k, v1, v2 ->
            v1
            |> Kernel.++(v2)
            |> Enum.sort()
          end)

        failing =
          Map.merge(acc[:failing], result[:failing], fn _k, v1, v2 ->
            v1
            |> Kernel.++(v2)
            |> Enum.sort()
          end)

        %{acc | passing: passing, failing: failing}
      end)

    log_failing_tests(completed_tests[:failing])

    for hardfork <- @hardforks do
      passing_tests = length(completed_tests[:passing][hardfork])
      failing_tests = length(completed_tests[:failing][hardfork])
      total_tests = passing_tests + failing_tests

      percentage =
        if total_tests == 0, do: 0, else: round(passing_tests / total_tests * 1000) / 10

      IO.puts("Passing #{hardfork} tests tests #{passing_tests}/#{total_tests}= #{percentage}%")
    end
  end

  defp log_failing_tests(failing_tests) do
    IO.puts("Failing tests")

    failing_tests
    |> dedup_tests()
    # credo:disable-for-next-line Credo.Check.Warning.IoInspect
    |> IO.inspect(limit: :infinity)
  end

  defp dedup_tests(tests) do
    Enum.into(tests, %{}, fn {fork, list_of_tests} ->
      {fork, Enum.dedup(list_of_tests)}
    end)
  end

  defp run_group_tests(directory_path) do
    test_group = Enum.fetch!(String.split(directory_path, "/"), -1)

    directory_path
    |> tests()
    |> Enum.reduce(@initial_state, fn test_path, completed_tests ->
      test_path
      |> read_state_test_file()
      |> Enum.reduce(completed_tests, fn {test_name, test}, completed_tests ->
        run_test(completed_tests, test_group, test_name, test)
      end)
    end)
  end

  defp run_test(completed_tests, test_group, test_name, test) do
    completed_tests =
      test["post"]
      |> Enum.reduce(completed_tests, fn {hardfork, _test_data}, completed_tests ->
        hardfork_configuration = EVM.Configuration.hardfork_config(hardfork)

        if hardfork_configuration do
          run_transaction(
            completed_tests,
            test_group,
            test_name,
            test,
            hardfork
          )
        else
          completed_tests
        end
      end)

    completed_tests
  end

  defp run_transaction(
         completed_tests,
         test_group,
         test_name,
         test,
         hardfork
       ) do
    {test_name, test}
    |> StateTestRunner.run_test(hardfork)
    |> Enum.reduce(completed_tests, fn result, completed_tests ->
      if result.state_root_mismatch || result.logs_hash_mismatch do
        update_in(completed_tests, [:failing, hardfork], &["#{test_group}/#{test_name}" | &1])
      else
        update_in(completed_tests, [:passing, hardfork], &["#{test_group}/#{test_name}" | &1])
      end
    end)
  end

  def dump_state(state) do
    state
    |> Trie.Inspector.all_values()
    |> Enum.map(fn {key, value} ->
      k = Base.encode16(key, case: :lower)
      v = value |> ExRLP.decode() |> Account.deserialize()
      {k, v}
    end)
    |> Enum.map(fn {address_key, account} ->
      IO.puts(address_key)
      IO.puts("  Balance: #{account.balance}")
      IO.puts("  Nonce: #{account.nonce}")
      IO.puts("  Storage Root:")
      IO.puts("  " <> Base.encode16(account.storage_root))
      IO.puts("  Code Hash")
      IO.puts("  " <> Base.encode16(account.code_hash))
    end)
  end

  def read_state_test_file(test_path) do
    test_path
    |> File.read!()
    |> Poison.decode!()
  end

  def state_test_file_name(group, test) do
    file_name = Path.join(~w(st#{group} #{test}.json))
    relative_path = Path.join(~w(.. .. ethereum_common_tests GeneralStateTests #{file_name}))

    System.cwd()
    |> Path.join(relative_path)
    |> Path.expand()
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
end

GenerateStateTests.run(System.argv())
