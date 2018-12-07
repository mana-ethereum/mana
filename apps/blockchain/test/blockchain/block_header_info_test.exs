defmodule Blockchain.BlockHeaderInfoTest do
  use ExUnit.Case, async: true
  doctest Blockchain.BlockHeaderInfo

  describe ".get_ancestor_header/2" do
    test "returns the parent header if passed 1" do
      trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())

      parent_header = %Block.Header{
        number: 3,
        parent_hash: <<1, 3, 4>>,
        beneficiary: <<2, 3, 4>>,
        difficulty: 100,
        timestamp: 11,
        mix_hash: <<1>>,
        nonce: <<2>>
      }

      header = %Block.Header{
        number: 4,
        parent_hash: Block.Header.hash(parent_header),
        beneficiary: <<2, 3, 4>>,
        difficulty: 100,
        timestamp: 11,
        mix_hash: <<1>>,
        nonce: <<2>>,
        size: 415,
        total_difficulty: 100
      }

      parent_block = %Blockchain.Block{
        header: parent_header
      }

      block = %Blockchain.Block{
        header: header
      }

      Blockchain.Block.put_block(parent_block, trie)
      Blockchain.Block.put_block(block, trie)

      ancestor_header =
        block.header
        |> Blockchain.BlockHeaderInfo.new(trie)
        |> Blockchain.BlockHeaderInfo.get_ancestor_header(1)

      assert parent_header == ancestor_header
    end

    test "gets the header of the nth ancestor" do
      trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())

      grand_parent_header = %Block.Header{
        number: 3,
        parent_hash: <<1, 2, 3>>,
        beneficiary: <<2, 3, 4>>,
        difficulty: 100,
        timestamp: 11,
        mix_hash: <<1>>,
        nonce: <<2>>
      }

      parent_header = %Block.Header{
        number: 4,
        parent_hash: Block.Header.hash(grand_parent_header),
        beneficiary: <<2, 3, 4>>,
        difficulty: 100,
        timestamp: 11,
        mix_hash: <<1>>,
        nonce: <<2>>
      }

      header = %Block.Header{
        number: 5,
        parent_hash: Block.Header.hash(parent_header),
        beneficiary: <<2, 3, 4>>,
        difficulty: 100,
        timestamp: 11,
        mix_hash: <<1>>,
        nonce: <<2>>,
        size: 415,
        total_difficulty: 100
      }

      grand_parent_block = %Blockchain.Block{
        header: grand_parent_header
      }

      parent_block = %Blockchain.Block{
        header: parent_header
      }

      block = %Blockchain.Block{
        header: header
      }

      Blockchain.Block.put_block(grand_parent_block, trie)
      Blockchain.Block.put_block(parent_block, trie)
      Blockchain.Block.put_block(block, trie)

      ancestor_header =
        block.header
        |> Blockchain.BlockHeaderInfo.new(trie)
        |> Blockchain.BlockHeaderInfo.get_ancestor_header(2)

      assert grand_parent_header == ancestor_header
    end

    test "returns nil if n > 256" do
      db = MerklePatriciaTree.Test.random_ets_db()
      header = %Block.Header{}

      ancestor_header =
        header
        |> Blockchain.BlockHeaderInfo.new(MerklePatriciaTree.Trie.new(db))
        |> Blockchain.BlockHeaderInfo.get_ancestor_header(257)

      assert is_nil(ancestor_header)
    end

    test "returns nil if n < 0" do
      db = MerklePatriciaTree.Test.random_ets_db()
      header = %Block.Header{}

      ancestor_header =
        header
        |> Blockchain.BlockHeaderInfo.new(MerklePatriciaTree.Trie.new(db))
        |> Blockchain.BlockHeaderInfo.get_ancestor_header(-1)

      assert is_nil(ancestor_header)
    end

    test "returns nil if passed 0" do
      db = MerklePatriciaTree.Test.random_ets_db()

      header = %Block.Header{}

      ancestor_header =
        header
        |> Blockchain.BlockHeaderInfo.new(MerklePatriciaTree.Trie.new(db))
        |> Blockchain.BlockHeaderInfo.get_ancestor_header(0)

      assert is_nil(ancestor_header)
    end
  end
end
