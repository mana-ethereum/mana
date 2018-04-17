defmodule Blockchain.StateTest do
  alias MerklePatriciaTree.Trie
  alias Blockchain.Account

  use EthCommonTest.Harness
  use ExUnit.Case, async: true

  @passing_tests_by_group %{
    stExample: [:add11],
    stCallCodes: [
      :callcall_00,
      :callcode_checkPC,
    ],
  }

  test "Blockchain state tests" do
    for {test_group_name, test_group} <- @passing_tests_by_group do
      for {_test_name, test} <- passing_tests(test_group_name, test_group) do
        state = account_interface(test).state
        transaction = %Blockchain.Transaction{
          nonce: load_integer(test["transaction"]["nonce"]),
          gas_price: load_integer(test["transaction"]["gasPrice"]),
          gas_limit: load_integer(List.first(test["transaction"]["gasLimit"])),
          to: maybe_hex(test["transaction"]["to"]),
          value: load_integer(List.first(test["transaction"]["value"])),
        }
          |> Blockchain.Transaction.Signature.sign_transaction(maybe_hex(test["transaction"]["secretKey"]))


        {state, _, _} = Blockchain.Transaction.execute_transaction(
          state,
          transaction,
          %Block.Header{beneficiary: maybe_hex(test["env"]["currentCoinbase"])}
        )

        assert state.root_hash == maybe_hex(List.first(test["post"]["Frontier"])["hash"])
      end
    end
  end

  def dump_state(state) do
    state
      |> MerklePatriciaTree.Trie.Inspector.all_values()
      |> Enum.map(fn({key, value}) ->
        {
          key |> Base.encode16(case: :lower),
          value |> ExRLP.decode() |> Blockchain.Account.deserialize()
        }
      end)
      |> Enum.map(fn({address_key, account}) ->
        IO.puts address_key
        IO.puts "  Balance: #{account.balance}"
        IO.puts "  Nonce: #{account.nonce}"
        IO.puts "  Storage Root:"
        IO.puts "  " <> (account.storage_root |> Base.encode16)
        IO.puts "  Code Hash"
        IO.puts "  " <> (account.code_hash |> Base.encode16)
      end)

  end

  def passing_tests(test_group_name, test_group) do
    test_group
      |> Enum.filter(fn(test_name) ->
        test_group == :all || Enum.member?(test_group, test_name)
      end)
      |> Enum.map(fn(test_name) ->
        {test_name, read_state_test_file(test_group_name, test_name)}
      end)
  end

  def read_state_test_file(type, test_name) do
    {:ok, body} = File.read(state_test_file_name(type, test_name))
    Poison.decode!(body)[Atom.to_string(test_name)]
  end

  def state_test_file_name(type, test) do
    System.cwd() <> "/test/support/ethereum_common_tests/GeneralStateTests/#{Atom.to_string(type)}/#{test}.json"
  end

  def account_interface(test) do
    db = MerklePatriciaTree.Test.random_ets_db()
    empty_root_hash = ExRLP.encode(<<>>) |> BitHelper.kec()
    state = %Trie{
      db: db,
      root_hash: maybe_hex(test["env"]["previousHash"]),
    }

    state = Enum.reduce(test["pre"], state, fn({address, account}, state) ->
      storage = %Trie{root_hash: empty_root_hash}
      storage = Enum.reduce(account["storage"], storage, fn({key, value}, trie) ->
        trie
          |> Trie.update(load_integer(key), load_integer(value))
      end)
      state
        |> Account.put_account(
          maybe_hex(address),
          %Blockchain.Account{
            nonce: load_integer(account["nonce"]),
            balance: load_integer(account["balance"]),
            storage_root: storage.root_hash,
          })
          |> Blockchain.Account.put_code(maybe_hex(address), maybe_hex(account["code"]))
    end)

    Blockchain.Interface.AccountInterface.new(state)
  end
end
