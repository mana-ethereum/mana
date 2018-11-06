defmodule Blockchain.StateTest do
  use ExUnit.Case, async: true
  alias Blockchain.State
  doctest State

  alias Block.Header
  alias Blockchain.{Block, Blocktree}
  alias MerklePatriciaTree.DB.ETS

  test "it saves and loads a tree" do
    db = ETS.init(:state_test_0)

    tree = %Blocktree{
      best_block: %Block{
        block_hash: <<1::256>>,
        header: %Header{},
        transactions: [],
        receipts: [],
        ommers: []
      }
    }

    assert :ok == State.save_tree(db, tree)

    assert State.load_tree(db) == tree
  end
end
