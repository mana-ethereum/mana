defmodule RopstenTest do
  @moduledoc """
  This test case has the first n blocks of Ropsten,
  which we will verify and add to a block tree.
  As we process in our progress with Mana,
  we will be able to load and verify more of the Ropsten chain.
  """

  use ExUnit.Case, async: true

  alias Blockchain.{Chain, Block, Blocktree}

  @n 11

  setup_all do
    blocks =
      File.read!("test/support/ropsten.dat")
      |> BitHelper.from_hex()
      |> ExRLP.decode()
      |> Enum.map(fn block ->
        block |> ExRLP.decode() |> Block.deserialize()
      end)
      |> Enum.take(@n)

    {:ok, %{blocks: blocks}}
  end

  test "processing the first #{@n} blocks of the live ropsten block tree", %{blocks: blocks} do
    db = MerklePatriciaTree.Test.random_ets_db()
    tree = Blocktree.new()
    chain = Chain.load_chain(:ropsten)

    Enum.reduce(blocks, tree, fn block, tree ->
      {:ok, new_tree} = Blocktree.verify_and_add_block(tree, chain, block, db)

      new_tree
    end)
  end
end
