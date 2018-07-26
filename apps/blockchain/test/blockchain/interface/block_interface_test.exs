defmodule Blockchain.Interface.BlockInterfaceTest do
  use ExUnit.Case, async: true
  doctest Blockchain.Interface.BlockInterface
  doctest EVM.Interface.BlockInterface.Blockchain.Interface.BlockInterface

  describe ".get_ancestor_header/2" do
    test "returns own header if passed 0" do
      db = MerklePatriciaTree.Test.random_ets_db()

      header = %Block.Header{
        number: 2,
        parent_hash: <<1, 3, 2>>,
        beneficiary: <<2, 3, 4>>,
        difficulty: 100,
        timestamp: 11,
        mix_hash: <<1>>,
        nonce: <<2>>
      }

      block = %Blockchain.Block{
        header: header
      }

      Blockchain.Block.put_block(block, db)

      assert header ===
               Blockchain.Interface.BlockInterface.new(block.header, db)
               |> EVM.Interface.BlockInterface.get_ancestor_header(0)
    end

    test "returns the parent header if passed 1" do
      db = MerklePatriciaTree.Test.random_ets_db()

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
        nonce: <<2>>
      }

      parent_block = %Blockchain.Block{
        header: parent_header
      }

      block = %Blockchain.Block{
        header: header
      }

      Blockchain.Block.put_block(parent_block, db)
      Blockchain.Block.put_block(block, db)

      assert parent_header ===
               Blockchain.Interface.BlockInterface.new(block.header, db)
               |> EVM.Interface.BlockInterface.get_ancestor_header(1)
    end

    test "gets the header of the nth ancestor" do
      db = MerklePatriciaTree.Test.random_ets_db()

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
        nonce: <<2>>
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

      Blockchain.Block.put_block(grand_parent_block, db)
      Blockchain.Block.put_block(parent_block, db)
      Blockchain.Block.put_block(block, db)

      assert grand_parent_header ===
               block.header
               |> Blockchain.Interface.BlockInterface.new(db)
               |> EVM.Interface.BlockInterface.get_ancestor_header(2)
    end
  end

  test "returns nil if n > 256" do
    db = MerklePatriciaTree.Test.random_ets_db()
    header = %Block.Header{}

    assert nil ==
             header
             |> Blockchain.Interface.BlockInterface.new(db)
             |> EVM.Interface.BlockInterface.get_ancestor_header(257)
  end

  test "returns nil if n < 0" do
    db = MerklePatriciaTree.Test.random_ets_db()
    header = %Block.Header{}

    assert nil ==
             header
             |> Blockchain.Interface.BlockInterface.new(db)
             |> EVM.Interface.BlockInterface.get_ancestor_header(-1)
  end
end
