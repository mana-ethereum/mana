defmodule EthCommonTest.StateTestRunner do
  alias MerklePatriciaTree.Trie
  alias Blockchain.{Account, Chain, Transaction}
  alias Blockchain.Account.Repo
  alias Blockchain.Account.Storage
  alias ExthCrypto.Hash.Keccak

  import EthCommonTest.Helpers

  def run(test_path, :all) do
    ["Byzantium", "Constantinople", "TangerineWhistle", "SpuriousDragon", "Frontier", "Homestead"]
    |> Enum.flat_map(&run(test_path, &1))
  end

  def run(test_path, hardfork) do
    test_path
    |> read_state_test_file()
    |> Stream.filter(&fork_test?(&1, hardfork))
    |> Enum.flat_map(&run_test(&1, hardfork))
  end

  defp fork_test?({_test_name, test_data}, fork) do
    tests_suite_fork = test_suite_fork_name(fork)

    case Map.fetch(test_data["post"], tests_suite_fork) do
      {:ok, _test_data} -> true
      _ -> false
    end
  end

  def run_test({test_name, test}, hardfork) do
    hardfork = test_suite_fork_name(hardfork)
    human_readable_hardfork = human_readable_fork_name(hardfork)
    chain = Chain.test_config(human_readable_hardfork)

    test["post"][hardfork]
    |> Enum.with_index()
    |> Enum.map(fn {post, index} ->
      pre_state =
        test
        |> setup_state()
        |> create_accounts(test)

      indexes = post["indexes"]
      gas_limit_index = indexes["gas"]
      value_index = indexes["value"]
      data_index = indexes["data"]

      transaction =
        %Transaction{
          nonce: load_integer(test["transaction"]["nonce"]),
          gas_price: load_integer(test["transaction"]["gasPrice"]),
          gas_limit: load_integer(Enum.at(test["transaction"]["gasLimit"], gas_limit_index)),
          to: maybe_hex(test["transaction"]["to"]),
          value: load_integer(Enum.at(test["transaction"]["value"], value_index))
        }
        |> populate_init_or_data(maybe_hex(Enum.at(test["transaction"]["data"], data_index)))
        |> Transaction.Signature.sign_transaction(maybe_hex(test["transaction"]["secretKey"]))

      {account_repo, _, receipt} =
        Transaction.execute_with_validation(
          pre_state,
          transaction,
          %Block.Header{
            beneficiary: maybe_hex(test["env"]["currentCoinbase"]),
            difficulty: load_integer(test["env"]["currentDifficulty"]),
            timestamp: load_integer(test["env"]["currentTimestamp"]),
            number: load_integer(test["env"]["currentNumber"]),
            gas_limit: load_integer(test["env"]["currentGasLimit"]),
            parent_hash: maybe_hex(test["env"]["previousHash"])
          },
          chain
        )

      account_repo =
        account_repo
        |> simulate_miner_reward(test)
        |> simulate_account_cleaning(test, chain.evm_config)

      state = Repo.commit(account_repo).state

      expected_hash =
        test["post"][hardfork]
        |> Enum.at(index)
        |> Map.fetch!("hash")
        |> maybe_hex()

      expected_logs = test["post"][hardfork] |> Enum.at(index) |> Map.fetch!("logs")
      logs_hash = logs_hash(receipt.logs)

      %{
        hardfork: human_readable_hardfork,
        test_name: test_name,
        test_source: test["_info"]["source"],
        state_root_mismatch: state.root_hash != expected_hash,
        state_root_expected: expected_hash,
        state_root_actual: state.root_hash,
        logs_hash_mismatch: maybe_hex(expected_logs) != logs_hash,
        logs_hash_expected: maybe_hex(expected_logs),
        logs_hash_actual: logs_hash
      }
    end)
  end

  defp populate_init_or_data(tx, data) do
    if Transaction.contract_creation?(tx) do
      %{tx | init: data}
    else
      %{tx | data: data}
    end
  end

  defp setup_state(test) do
    db = MerklePatriciaTree.Test.random_ets_db()

    %Trie{
      db: db,
      root_hash: maybe_hex(test["env"]["previousHash"])
    }
  end

  defp create_accounts(state, test) do
    db = state.db

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
            {subtrie, _trie} = Storage.put(trie, trie.root_hash, load_integer(key), value)

            subtrie
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
  end

  defp logs_hash(logs) do
    logs
    |> ExRLP.encode()
    |> Keccak.kec()
  end

  def read_state_test_file(test_path) do
    test_path
    |> File.read!()
    |> Jason.decode!()
  end

  defp simulate_miner_reward(account_repo, test) do
    coinbase = maybe_hex(test["env"]["currentCoinbase"])
    Repo.add_wei(account_repo, coinbase, 0)
  end

  defp simulate_account_cleaning(account_repo, test, hardfork_configuration) do
    coinbase = maybe_hex(test["env"]["currentCoinbase"])

    Blockchain.Transaction.AccountCleaner.clean_touched_accounts(
      account_repo,
      [coinbase],
      hardfork_configuration
    )
  end
end
