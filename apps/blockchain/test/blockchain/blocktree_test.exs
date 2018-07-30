defmodule Blockchain.BlocktreeTest do
  use ExUnit.Case, async: true
  doctest Blockchain.Blocktree
  alias Blockchain.Blocktree

  describe ".verify_and_add_block/6" do
    test "adds valid blocks" do
      trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      chain = Blockchain.Chain.load_chain(:ropsten)
      parent = Blockchain.Genesis.create_block(chain, trie.db)
      child = Blockchain.Block.gen_child_block(parent, chain)

      block_1 = %Blockchain.Block{
        header: %Block.Header{
          number: 0,
          parent_hash: <<0::256>>,
          beneficiary: <<2, 3, 4>>,
          difficulty: 1_048_576,
          timestamp: 0,
          gas_limit: 200_000,
          mix_hash: <<1>>,
          nonce: <<2>>,
          state_root: parent.header.state_root
        }
      }

      block_2 =
        %Blockchain.Block{
          header: %Block.Header{
            number: 1,
            parent_hash: block_1 |> Blockchain.Block.hash(),
            beneficiary: <<2::160>>,
            difficulty: 997_888,
            timestamp: 1_479_642_530,
            gas_limit: 200_000,
            mix_hash: <<1>>,
            nonce: <<2>>,
            state_root: child.header.state_root
          }
        }
        |> Blockchain.Block.add_rewards(trie.db)

      tree = Blockchain.Blocktree.new_tree()
      {:ok, tree_1} = Blockchain.Blocktree.verify_and_add_block(tree, chain, block_1, trie.db)
      {:ok, tree_2} = Blockchain.Blocktree.verify_and_add_block(tree_1, chain, block_2, trie.db)

      inspected_tree = Blockchain.Blocktree.inspect_tree(tree_2)

      assert inspected_tree == [
               :root,
               [
                 {0, Blockchain.Block.hash(block_1)},
                 [
                   {1, Blockchain.Block.hash(block_2)}
                 ]
               ]
             ]
    end
  end

  test "multi-level tree" do
    block_10 = %Blockchain.Block{
      block_hash: <<10>>,
      header: %Block.Header{number: 0, parent_hash: <<0::256>>, difficulty: 100}
    }

    block_20 = %Blockchain.Block{
      block_hash: <<20>>,
      header: %Block.Header{number: 1, parent_hash: <<10>>, difficulty: 110}
    }

    block_21 = %Blockchain.Block{
      block_hash: <<21>>,
      header: %Block.Header{number: 1, parent_hash: <<10>>, difficulty: 120}
    }

    block_30 = %Blockchain.Block{
      block_hash: <<30>>,
      header: %Block.Header{number: 2, parent_hash: <<20>>, difficulty: 120}
    }

    block_40 = %Blockchain.Block{
      block_hash: <<40>>,
      header: %Block.Header{number: 3, parent_hash: <<30>>, difficulty: 120}
    }

    tree =
      Blocktree.new_tree()
      |> Blocktree.add_block(block_10)
      |> Blocktree.add_block(block_20)
      |> Blocktree.add_block(block_21)
      |> Blocktree.add_block(block_30)
      |> Blocktree.add_block(block_40)

    assert Blocktree.inspect_tree(tree) ==
             [
               :root,
               [
                 {0, <<10>>},
                 [
                   {1, <<20>>},
                   [
                     {2, <<30>>},
                     [{3, <<40>>}]
                   ]
                 ],
                 [
                   {1, <<21>>}
                 ]
               ]
             ]
  end
end
