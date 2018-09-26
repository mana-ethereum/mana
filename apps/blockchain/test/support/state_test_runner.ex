defmodule StateTestRunner do
  alias MerklePatriciaTree.Trie
  alias Blockchain.{Account, Transaction}
  alias Blockchain.Interface.AccountInterface
  alias Blockchain.Account.Storage
  alias ExthCrypto.Hash.Keccak

  import EthCommonTest.Helpers

  def run(test_path, :all) do
    ["Byzantium", "Constantinople", "EIP150", "EIP158", "Frontier", "Homestead"]
    |> Enum.flat_map(&run(test_path, &1))
  end

  def run(test_path, hardfork) do
    test_path
    |> read_state_test_file()
    |> Stream.filter(&fork_test?(&1, hardfork))
    |> Enum.flat_map(&run_test(&1, hardfork))
  end

  defp fork_test?({_test_name, test_data}, fork) do
    case Map.fetch(test_data["post"], fork) do
      {:ok, _test_data} -> true
      _ -> false
    end
  end

  defp run_test({test_name, test}, hardfork) do
    hardfork_configuration = EVM.Configuration.hardfork_config(hardfork)

    test["post"][hardfork]
    |> Enum.with_index()
    |> Enum.map(fn {post, index} ->
      pre_state = account_interface(test).state

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

      result =
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
          hardfork_configuration
        )

      {state, logs} =
        case result do
          {state, _, logs, _tx_status} -> {state, logs}
          _ -> {pre_state, []}
        end

      expected_hash =
        test["post"][hardfork]
        |> Enum.at(index)
        |> Map.fetch!("hash")
        |> maybe_hex()

      expected_logs = test["post"][hardfork] |> Enum.at(index) |> Map.fetch!("logs")
      logs_hash = logs_hash(logs)

      %{
        hardfork: hardfork,
        test_name: test_name,
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

  defp logs_hash(logs) do
    logs
    |> ExRLP.encode()
    |> Keccak.kec()
  end

  def read_state_test_file(test_path) do
    test_path
    |> File.read!()
    |> Poison.decode!()
  end
end
