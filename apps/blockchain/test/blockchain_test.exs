defmodule BlockchainTest do
  use ExUnit.Case
  use EthCommonTest.Harness
  alias Blockchain.{Block, Blocktree}
  alias MerklePatriciaTree.Trie
  alias Blockchain.Account
  alias Blockchain.Account.Storage

  doctest Blockchain

  @ethereum_common_tests_path "/../../ethereum_common_tests/BlockchainTests/"
  @test "/GeneralStateTests/stSystemOperationsTest/ABAcalls0_d0g0v0"

  test "runs blockchain common tests" do
    @test
    |> read_test()
    |> run_test()
    # |> assert_state()
  end

  defp read_test(relative_path) do
    path = System.cwd() <> @ethereum_common_tests_path <> relative_path <> ".json"

    path
    |> File.read!()
    |> Poison.decode!()
    |> Map.fetch!("ABAcalls0_d0g0v0_Frontier")
  end

  defp run_test(json_test) do
    blocktree =
      create_blocktree()
      |> add_genesis_block(json_test)

    state = populate_prestate(json_test)

    add_blocks(json_test, blocktree, state)
  end

  defp add_genesis_block(blocktree, json_test) do
    genesis_block =
      json_test["genesisRLP"]
      |> maybe_hex()
      |> ExRLP.decode
      |> Block.deserialize

    Blocktree.add_block(blocktree, genesis_block)
  end

  defp create_blocktree do
    Blocktree.new_tree()
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
