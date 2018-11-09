defmodule ExWire.Struct.BlockQueueTest do
  use ExUnit.Case, async: true
  doctest ExWire.Struct.BlockQueue

  test "add_header/7" do
    chain = Blockchain.Test.ropsten_chain()
    db = MerklePatriciaTree.Test.random_ets_db(:proces_block_queue)

    header = %Block.Header{
      number: 5,
      parent_hash: <<0::256>>,
      beneficiary: <<2, 3, 4>>,
      difficulty: 100,
      timestamp: 11,
      mix_hash: <<1>>,
      nonce: <<2>>
    }

    header_hash =
      <<78, 28, 127, 10, 192, 253, 127, 239, 254, 179, 39, 34, 245, 44, 152, 98, 128, 71, 238,
        155, 100, 161, 199, 71, 243, 223, 172, 191, 74, 99, 128, 63>>

    assert {block_queue, block_tree, _block_trie, false} =
             ExWire.Struct.BlockQueue.add_header(
               %ExWire.Struct.BlockQueue{do_validation: false},
               Blockchain.Blocktree.new_tree(),
               header,
               header_hash,
               "remote_id",
               chain,
               MerklePatriciaTree.Trie.new(db)
             )

    assert block_queue.queue == %{}
    assert block_tree.best_block.header.number == 5

    # TODO: Add a second addition example
  end

  test "add_block_struct/5" do
    chain = Blockchain.Test.ropsten_chain()
    db = MerklePatriciaTree.Test.random_ets_db(:add_block_struct)

    header = %Block.Header{
      transactions_root:
        <<200, 70, 164, 239, 152, 124, 5, 149, 40, 10, 157, 9, 210, 181, 93, 89, 5, 119, 158, 112,
          221, 58, 94, 86, 206, 113, 120, 51, 241, 9, 154, 150>>,
      ommers_hash:
        <<109, 111, 130, 71, 136, 238, 173, 201, 249, 31, 178, 95, 22, 55, 184, 127, 214, 229,
          135, 243, 4, 81, 0, 18, 81, 183, 165, 189, 6, 18, 197, 174>>
    }

    block_struct = %ExWire.Struct.Block{
      transactions_rlp: [[1], [2], [3]],
      transactions: ["trx"],
      ommers_rlp: [[1]],
      ommers: ["ommers"]
    }

    block_queue = %ExWire.Struct.BlockQueue{
      queue: %{
        1 => %{
          <<1::256>> => %{
            commitments: MapSet.new([]),
            header: header,
            block: %Blockchain.Block{header: header, block_hash: <<1::256>>},
            ready: false
          }
        }
      },
      do_validation: false
    }

    assert {block_queue, _block_tree, _trie} =
             ExWire.Struct.BlockQueue.add_block_struct(
               block_queue,
               Blockchain.Blocktree.new_tree(),
               block_struct,
               chain,
               db
             )

    assert block_queue.queue[1][<<1::256>>].block.transactions == ["trx"]
    assert block_queue.queue[1][<<1::256>>].block.ommers == ["ommers"]
  end

  test "process_block_queue/4" do
    chain = Blockchain.Test.ropsten_chain()
    db = MerklePatriciaTree.Test.random_ets_db(:process_block_queue)

    header = %Block.Header{
      number: 1,
      parent_hash: <<0::256>>,
      beneficiary: <<2, 3, 4>>,
      difficulty: 100,
      timestamp: 11,
      mix_hash: <<1>>,
      nonce: <<2>>
    }

    block_queue = %ExWire.Struct.BlockQueue{
      queue: %{
        1 => %{
          <<1::256>> => %{
            commitments: MapSet.new([1, 2]),
            header: header,
            block: %Blockchain.Block{header: header, block_hash: <<1::256>>},
            ready: true
          }
        }
      },
      do_validation: false
    }

    assert {new_block_queue, block_tree, _new_trie} =
             ExWire.Struct.BlockQueue.process_block_queue(
               block_queue,
               Blockchain.Blocktree.new_tree(),
               chain,
               MerklePatriciaTree.Trie.new(db)
             )

    assert block_tree.best_block.header.number == 1
    assert new_block_queue.queue == %{}
  end
end
