defmodule Blockchain.BlocktreeTest do
  use ExUnit.Case, async: true
  doctest Blockchain.Blocktree
  alias Blockchain.Blocktree

  describe ".verify_and_add_block/6" do
    test "adds valid blocks" do
      trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      chain = Blockchain.Chain.load_chain(:ropsten)
      {parent, _trie} = Blockchain.Genesis.create_block(chain, trie)
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

      {block_2, _new_trie} =
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
        |> Blockchain.Block.add_rewards(trie, chain)

      tree = Blocktree.new_tree()
      {:ok, tree_1} = Blocktree.verify_and_add_block(tree, chain, block_1, trie.db)
      {:ok, tree_2} = Blocktree.verify_and_add_block(tree_1, chain, block_2, trie.db)

      assert tree_2.best_block.header.number == block_2.header.number
    end

    test "adds a genesis block" do
      trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      chain = Blockchain.Chain.load_chain(:ropsten)

      gen_block = %Blockchain.Block{
        header: %Block.Header{
          number: 0,
          parent_hash: <<0::256>>,
          beneficiary: <<2, 3, 4>>,
          difficulty: 0x100000,
          gas_limit: 0x1000000,
          timestamp: 11,
          mix_hash: <<1>>,
          nonce: <<2>>,
          state_root:
            <<33, 123, 11, 188, 251, 114, 226, 213, 126, 40, 243, 60, 179, 97, 185, 152, 53, 19,
              23, 119, 85, 220, 63, 51, 206, 62, 112, 34, 237, 98, 183, 123>>
        }
      }

      tree = Blockchain.Blocktree.new_tree()

      {:ok, tree_1} =
        Blockchain.Blocktree.verify_and_add_block(tree, chain, gen_block, trie.db, false)

      assert tree_1.best_block.header.number == 0
    end

    test "adds invalid block" do
      trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      chain = Blockchain.Chain.load_chain(:ropsten)
      {parent, _new_trie} = Blockchain.Genesis.create_block(chain, trie)

      block_1 = %Blockchain.Block{
        header: %Block.Header{
          number: 0,
          parent_hash: <<0::256>>,
          beneficiary: <<2, 3, 4>>,
          difficulty: 1_048_576,
          timestamp: 11,
          gas_limit: 200_000,
          mix_hash: <<1>>,
          nonce: <<2>>,
          state_root: parent.header.state_root
        }
      }

      block_2 = %Blockchain.Block{
        header: %Block.Header{
          number: 1,
          parent_hash: block_1 |> Blockchain.Block.hash(),
          beneficiary: <<2, 3, 4>>,
          difficulty: 110,
          timestamp: 11,
          mix_hash: <<1>>,
          nonce: <<2>>
        }
      }

      tree = Blockchain.Blocktree.new_tree()
      {:ok, tree_1} = Blockchain.Blocktree.verify_and_add_block(tree, chain, block_1, trie.db)

      result = Blockchain.Blocktree.verify_and_add_block(tree_1, chain, block_2, trie.db)

      assert result ==
               {:invalid, [:invalid_difficulty, :invalid_gas_limit, :child_timestamp_invalid]}
    end
  end

  describe "get_best_block/3" do
    test "when there's no best block" do
      trie = MerklePatriciaTree.Test.random_ets_db() |> MerklePatriciaTree.Trie.new()
      chain = Blockchain.Chain.load_chain(:ropsten)
      tree = Blocktree.new_tree()

      assert {:ok, {block, new_trie}} = Blockchain.Blocktree.get_best_block(tree, chain, trie)

      assert block.header.number == 0
    end

    test "when there is a best block" do
      db = MerklePatriciaTree.Test.random_ets_db()
      chain = Blockchain.Chain.load_chain(:ropsten)

      block = %Blockchain.Block{
        transactions: [
          %Blockchain.Transaction{
            nonce: 5,
            gas_price: 6,
            gas_limit: 7,
            to: <<1::160>>,
            value: 8,
            v: 27,
            r: 9,
            s: 10,
            data: "hi"
          }
        ],
        header: %Block.Header{
          number: 5,
          parent_hash: <<1, 2, 3>>,
          beneficiary: <<2, 3, 4>>,
          difficulty: 100,
          timestamp: 11,
          mix_hash: <<1>>,
          nonce: <<2>>
        }
      }

      tree = %Blocktree{best_block: block}

      assert {:ok, block} == Blockchain.Blocktree.get_best_block(tree, chain, db)
    end
  end
end
