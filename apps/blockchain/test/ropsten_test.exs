defmodule RopstenTest do
  @moduledoc """
  This test case has the first n blocks of Ropsten, which we
  will verify and add to a block tree. As we process in our
  progress with Exthereum, we will be able to load and verify
  more of the Ropsten chain.
  """

  use ExUnit.Case, async: true

  @n 11

  setup_all do
    blocks =
      File.read!("test/support/ropsten_blocks.dat")
      |> BitHelper.from_hex()
      |> ExRLP.decode()
      |> Enum.map(fn block ->
        block |> ExRLP.decode() |> Blockchain.Block.deserialize()
      end)
      |> Enum.take(@n)

    {:ok,
     %{
       blocks: blocks
     }}
  end

  test "processing the first #{@n} blocks of the live ropsten block tree", %{blocks: blocks} do
    db = MerklePatriciaTree.Test.random_ets_db()
    tree = Blockchain.Blocktree.new_tree()
    chain = Blockchain.Test.ropsten_chain()

    Enum.reduce(blocks, tree, fn block, tree ->
      {:ok, new_tree} = Blockchain.Blocktree.verify_and_add_block(tree, chain, block, db)

      new_tree
    end)
  end
end
