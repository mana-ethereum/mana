defmodule Blockchain.BlocktreeTest do
  use ExUnit.Case, async: true

  doctest Blockchain.Blocktree

  alias EthCore.Block.Header
  alias Blockchain.{Blocktree, Block, Chain, Genesis}

  describe "new/0" do
    test "correctly creates a new Blocktree" do
      expected = %Blocktree{
        block: :root,
        children: %{},
        total_difficulty: 0,
        parent_map: %{}
      }

      assert Blocktree.new() == expected
    end
  end

  describe "get_canonical_block/1" do
    test "root canonical block" do
      block = Blocktree.new() |> Blocktree.get_canonical_block()
      assert block == :root
    end

    test "single canonical block" do
      block_1 = %Block{
        block_hash: <<1>>,
        header: %Header{number: 0, parent_hash: <<0::256>>, difficulty: 100}
      }

      expected = %Block{
        block_hash: <<1>>,
        header: %Header{
          difficulty: 100,
          number: 0,
          parent_hash: <<0::256>>
        }
      }

      block =
        Blocktree.new()
        |> Blocktree.add_block(block_1)
        |> Blocktree.get_canonical_block()

      assert block == expected
    end

    test "several blocks" do
      block_10 = %Block{
        block_hash: <<10>>,
        header: %Header{number: 5, parent_hash: <<0::256>>, difficulty: 100}
      }

      block_20 = %Block{
        block_hash: <<20>>,
        header: %Header{number: 6, parent_hash: <<10>>, difficulty: 110}
      }

      block_21 = %Block{
        block_hash: <<21>>,
        header: %Header{number: 6, parent_hash: <<10>>, difficulty: 109}
      }

      block_30 = %Block{
        block_hash: <<30>>,
        header: %Header{number: 7, parent_hash: <<20>>, difficulty: 120}
      }

      block_31 = %Block{
        block_hash: <<31>>,
        header: %Header{number: 7, parent_hash: <<20>>, difficulty: 119}
      }

      block_41 = %Block{
        block_hash: <<41>>,
        header: %Header{number: 8, parent_hash: <<30>>, difficulty: 129}
      }

      expected = %Block{
        block_hash: <<41>>,
        header: %Header{
          difficulty: 129,
          number: 8,
          parent_hash: <<30>>
        }
      }

      block =
        Blocktree.new()
        |> Blocktree.add_block(block_10)
        |> Blocktree.add_block(block_20)
        |> Blocktree.add_block(block_30)
        |> Blocktree.add_block(block_31)
        |> Blocktree.add_block(block_41)
        |> Blocktree.add_block(block_21)
        |> Blocktree.get_canonical_block()

      assert block == expected
    end
  end

  describe "verify_and_add_block/5" do
    test "genesis block" do
      trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      chain = Chain.load_chain(:ropsten)

      gen_block = %Block{
        header: %Header{
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

      tree = Blocktree.new()
      {:ok, tree_1} = Blocktree.verify_and_add_block(tree, chain, gen_block, trie.db)

      expected = [
        :root,
        [
          {0,
           <<71, 157, 104, 174, 116, 127, 80, 187, 43, 230, 237, 165, 124, 115, 132, 188, 112,
             248, 218, 117, 191, 179, 180, 121, 118, 244, 128, 207, 39, 194, 241, 152>>}
        ]
      ]

      assert Blocktree.inspect_tree(tree_1) == expected
    end

    test "valid block" do
      trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      chain = Chain.load_chain(:ropsten)
      parent = Genesis.new_block(chain, trie.db)
      child = Block.new_child(parent, chain)

      block_1 = %Block{
        header: %Header{
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
        %Block{
          header: %Header{
            number: 1,
            parent_hash: block_1 |> Block.hash(),
            beneficiary: <<2::160>>,
            difficulty: 997_888,
            timestamp: 1_479_642_530,
            gas_limit: 200_000,
            mix_hash: <<1>>,
            nonce: <<2>>,
            state_root: child.header.state_root
          }
        }
        |> Block.add_rewards(trie.db)

      tree = Blocktree.new()

      {:ok, tree_1} = Blocktree.verify_and_add_block(tree, chain, block_1, trie.db)
      {:ok, tree_2} = Blocktree.verify_and_add_block(tree_1, chain, block_2, trie.db)

      expected = [
        :root,
        [
          {0,
           <<155, 169, 162, 94, 229, 198, 27, 192, 121, 15, 154, 160, 41, 76, 199, 62, 154, 57,
             121, 20, 34, 43, 200, 107, 54, 247, 204, 195, 57, 60, 223, 204>>},
          [
            {1,
             <<46, 192, 123, 64, 63, 230, 19, 10, 150, 191, 251, 157, 226, 35, 183, 69, 92, 177,
               33, 66, 159, 174, 200, 202, 197, 69, 24, 216, 9, 107, 151, 192>>}
          ]
        ]
      ]

      assert Blocktree.inspect_tree(tree_2) == expected
    end

    test "invalid block" do
      trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      chain = Chain.load_chain(:ropsten)
      parent = Genesis.new_block(chain, trie.db)

      block_1 = %Block{
        header: %Header{
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

      block_2 = %Block{
        header: %Header{
          number: 1,
          parent_hash: block_1 |> Block.hash(),
          beneficiary: <<2, 3, 4>>,
          difficulty: 110,
          timestamp: 11,
          mix_hash: <<1>>,
          nonce: <<2>>
        }
      }

      tree = Blocktree.new()

      {:ok, tree_1} = Blocktree.verify_and_add_block(tree, chain, block_1, trie.db)

      expected = {
        :invalid,
        [
          :invalid_difficulty,
          :invalid_gas_limit,
          :child_timestamp_invalid
        ]
      }

      assert Blocktree.verify_and_add_block(tree_1, chain, block_2, trie.db) == expected
    end
  end

  describe "add_block/2" do
    test "adds a couple of simple blocks" do
      block_1 = %Block{
        block_hash: <<1>>,
        header: %Header{number: 5, parent_hash: <<0::256>>, difficulty: 100}
      }

      block_2 = %Block{
        block_hash: <<2>>,
        header: %Header{number: 6, parent_hash: <<1>>, difficulty: 110}
      }

      expected = %Blocktree{
        block: :root,
        children: %{
          <<1>> => %Blocktree{
            block: %Block{
              block_hash: <<1>>,
              header: %Header{difficulty: 100, number: 5, parent_hash: <<0::256>>}
            },
            children: %{
              <<2>> => %Blocktree{
                block: %Block{
                  block_hash: <<2>>,
                  header: %Header{difficulty: 110, number: 6, parent_hash: <<1>>}
                },
                children: %{},
                parent_map: %{},
                total_difficulty: 110
              }
            },
            total_difficulty: 110,
            parent_map: %{}
          }
        },
        total_difficulty: 110,
        parent_map: %{
          <<1>> => <<0::256>>,
          <<2>> => <<1>>
        }
      }

      blocktree =
        Blocktree.new()
        |> Blocktree.add_block(block_1)
        |> Blocktree.add_block(block_2)

      assert blocktree == expected
    end

    test "multi-level tree" do
      block_10 = %Block{
        block_hash: <<10>>,
        header: %Header{
          number: 0,
          parent_hash: <<0::256>>,
          difficulty: 100
        }
      }

      block_20 = %Block{
        block_hash: <<20>>,
        header: %Header{
          number: 1,
          parent_hash: <<10>>,
          difficulty: 110
        }
      }

      block_21 = %Block{
        block_hash: <<21>>,
        header: %Header{
          number: 1,
          parent_hash: <<10>>,
          difficulty: 120
        }
      }

      block_30 = %Block{
        block_hash: <<30>>,
        header: %Header{
          number: 2,
          parent_hash: <<20>>,
          difficulty: 120
        }
      }

      block_40 = %Block{
        block_hash: <<40>>,
        header: %Header{
          number: 3,
          parent_hash: <<30>>,
          difficulty: 120
        }
      }

      tree =
        Blocktree.new()
        |> Blocktree.add_block(block_10)
        |> Blocktree.add_block(block_20)
        |> Blocktree.add_block(block_21)
        |> Blocktree.add_block(block_30)
        |> Blocktree.add_block(block_40)

      expected = [
        :root,
        [
          {0, <<10>>},
          [
            {1, <<20>>},
            [
              {2, <<30>>},
              [
                {3, <<40>>}
              ]
            ]
          ],
          [
            {1, <<21>>}
          ]
        ]
      ]

      assert Blocktree.inspect_tree(tree) == expected
    end
  end

  describe "get_path_to_root/2" do
    test "depth 2" do
      blocktree = %Blocktree{parent_map: %{<<1>> => <<2>>, <<2>> => <<3>>, <<3>> => <<0::256>>}}
      assert Blocktree.get_path_to_root(blocktree, <<1>>) == {:ok, [<<3>>, <<2>>]}
    end

    test "depth 1" do
      blocktree = %Blocktree{parent_map: %{<<20>> => <<10>>, <<10>> => <<0::256>>}}
      assert Blocktree.get_path_to_root(blocktree, <<20>>) == {:ok, [<<10>>]}
    end

    test "depth 2 with ommers" do
      blocktree = %Blocktree{
        parent_map: %{
          <<30>> => <<20>>,
          <<31>> => <<20>>,
          <<20>> => <<10>>,
          <<21>> => <<10>>,
          <<10>> => <<0::256>>
        }
      }

      expected = {:ok, [<<10>>, <<20>>]}

      assert Blocktree.get_path_to_root(blocktree, <<30>>) == expected
    end

    test "depth 1 with ommers" do
      blocktree = %Blocktree{
        parent_map: %{
          <<30>> => <<20>>,
          <<31>> => <<20>>,
          <<20>> => <<10>>,
          <<21>> => <<10>>,
          <<10>> => <<0::256>>
        }
      }

      assert Blocktree.get_path_to_root(blocktree, <<20>>) == {:ok, [<<10>>]}
    end

    test "another depth 2 with ommers" do
      blocktree = %Blocktree{
        parent_map: %{
          <<30>> => <<20>>,
          <<31>> => <<20>>,
          <<20>> => <<10>>,
          <<21>> => <<10>>,
          <<10>> => <<0::256>>
        }
      }

      expected = {:ok, [<<10>>, <<20>>]}

      assert Blocktree.get_path_to_root(blocktree, <<31>>) == expected
    end

    test "non-existent root node" do
      blocktree = %Blocktree{
        parent_map: %{
          <<30>> => <<20>>,
          <<31>> => <<20>>,
          <<20>> => <<10>>,
          <<21>> => <<10>>,
          <<10>> => <<0::256>>
        }
      }

      assert Blocktree.get_path_to_root(blocktree, <<32>>) == :no_path
    end
  end

  describe "inspect/1" do
    test "returns a valid representation of the given BlockTree" do
      block_1 = %Block{
        block_hash: <<1>>,
        header: %Header{
          number: 0,
          parent_hash: <<0::256>>,
          difficulty: 100
        }
      }

      block_2 = %Block{
        block_hash: <<2>>,
        header: %Header{
          number: 1,
          parent_hash: <<0::256>>,
          difficulty: 110
        }
      }

      block_3 = %Block{
        block_hash: <<3>>,
        header: %Header{
          number: 2,
          parent_hash: <<0::256>>,
          difficulty: 120
        }
      }

      blocktree =
        Blocktree.new()
        |> Blocktree.add_block(block_1)
        |> Blocktree.add_block(block_2)
        |> Blocktree.add_block(block_3)
        |> Blocktree.inspect_tree()

      expected = [:root, [{0, <<1>>}], [{1, <<2>>}], [{2, <<3>>}]]

      assert blocktree == expected
    end
  end
end
