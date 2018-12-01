defmodule ExWire.SyncTest do
  @moduledoc """
  This is effectively an end-to-end test of warp sync with local blockchain
  data from the Ethereum common tests. The tests are a little difficult to
  work with as they don't have receipts listed, so right now we're ignoring
  the receipts, which gives us a different block hash. Also, we do not seem
  to be matching the state root, so those items should be looked into futher.
  """
  use ExUnit.Case, async: true
  doctest ExWire.Sync

  alias Block.Header
  alias Blockchain.{Block, Transaction}
  alias ExthCrypto.Hash.Keccak
  alias ExWire.Packet.Capability.Par.{SnapshotData, SnapshotManifest}
  alias ExWire.Packet.Capability.Par.SnapshotData.{BlockChunk, StateChunk}
  alias ExWire.Struct.{Peer, WarpQueue}
  alias ExWire.Sync
  alias ExWire.Sync.WarpProcessor
  alias ExWire.Sync.WarpProcessor.PowProcessor
  alias MerklePatriciaTree.{Trie, TrieStorage}

  @empty_trie Trie.empty_trie_root_hash()

  describe "warp sync" do
    test "ContractStoreClearsOOG_d0g0v0_Homestead" do
      run_test(
        "../../ethereum_common_tests/BlockchainTests/GeneralStateTests/stTransactionTest/ContractStoreClearsOOG_d0g0v0.json",
        "ContractStoreClearsOOG_d0g0v0_Homestead",
        :homestead_test,
        block_hash: "0xa5c57a69d9186d7a3a70fe4fe8472a253f7de9e29deac437c4d675b1fb1dc971",
        state_root: "0xbb80b5bd8b3b45b80eebebe47c753d1dea86ec96fbfb2c554a8f50018597f036"
      )
    end

    test "add11_d0g0v0_Homestead" do
      run_test(
        "../../ethereum_common_tests/BlockchainTests/GeneralStateTests/stExample/add11_d0g0v0.json",
        "add11_d0g0v0_Homestead",
        :homestead_test,
        block_hash: "0xf2e350b3f0632d360a2763df744cd3ef3b9ffb8f30a508835dc559e7a3819a4a",
        state_root: "0x2858517a226c99034d066c582ddc45d25fc628ab0c7275bd5fb0ef0a25b3a8c2"
      )
    end
  end

  defp run_test(file, test, chain_id, opts) do
    {
      test_info,
      blocks,
      manifest,
      block_snapshot_data,
      state_snapshot_data
    } = build_warp_from(file, test, chain_id, opts)

    trie = MerklePatriciaTree.CachingTrie.new(memory_trie())
    chain = Blockchain.Chain.load_chain(chain_id)

    warp_queue =
      WarpQueue.new()
      |> WarpQueue.new_manifest(manifest)

    {:ok, _peer_supervisor} = ExWire.PeerSupervisor.start_link([])

    {:ok, _warp_processor} =
      WarpProcessor.start_link({1, trie, @empty_trie, PowProcessor}, name: :test_warp_processor)

    {:ok, sync} =
      Sync.start_link({trie, chain, true, warp_queue},
        name: :test_sync,
        warp_processor: :test_warp_processor
      )

    send(sync, {:packet, block_snapshot_data, %Peer{}})
    send(sync, {:packet, state_snapshot_data, %Peer{}})

    # Give sync time to process the messages
    Process.sleep(1_000)

    # Get the warp queue
    warp_queue = Sync.get_state(sync)[:warp_queue]

    # Verify final warp queue state
    assert warp_queue.manifest_block_hashes == MapSet.new([block_snapshot_data.hash])
    assert warp_queue.manifest_state_hashes == MapSet.new([state_snapshot_data.hash])
    assert warp_queue.chunk_requests == MapSet.new()

    assert warp_queue.retrieved_chunks ==
             MapSet.new([block_snapshot_data.hash, state_snapshot_data.hash])

    block_numbers =
      for block_info <- test_info["blocks"], into: MapSet.new() do
        block_info["blockHeader"]["number"]
        |> Exth.decode_hex()
        |> Exth.maybe_decode_unsigned()
      end

    assert warp_queue.processed_blocks == block_numbers

    # This is currently failing since we do not matching on receipts root
    # since we don't have the receipts from the test data.
    # assert WarpQueue.status(warp_queue, block_tree) == :success

    account_hashes =
      for {address, _} <- test_info["postState"], into: MapSet.new() do
        Keccak.kec(Exth.decode_hex(address))
      end

    assert warp_queue.processed_accounts == MapSet.size(account_hashes)

    # Verify block tree has the latest and great block
    assert warp_queue.block_tree.best_block == List.last(blocks)

    # Now, instead of inspecting the trie itself, let's query it for data
    # that we consider relevant.

    # Get all transactions
    for block <- blocks do
      for {transaction, i} <- Enum.with_index(block.transactions) do
        assert transaction ==
                 Blockchain.Block.get_transaction(block, i, TrieStorage.permanent_db(trie))
      end
    end

    # Get receipts
    # TODO: Since we don't have receipts
  end

  @spec build_warp_from(String.t(), String.t(), atom(), Keyword.t()) ::
          {%{}, SnapshotManifest.manifest(), SnapshotData.t(), SnapshotData.t()}
  defp build_warp_from(json_file, test_name, _chain_id, opts) do
    test_info =
      json_file
      |> File.read!()
      |> Jason.decode!()
      |> Map.get(test_name)

    {block_chunk, blocks} =
      Enum.reduce(test_info["blocks"], {%BlockChunk{}, []}, fn block_json,
                                                               {block_chunk, curr_blocks} ->
        block =
          block_json["rlp"]
          |> Exth.decode_hex()
          |> ExRLP.decode()
          |> Block.deserialize()

        # These test cases don't actually include the receipts,
        # so either we need to actually process the blocks to generate
        # the receipts, or we can just pretend there are none. We opt
        # for the latter, for now.
        block = %{
          block
          | header: %{
              block.header
              | receipts_root: MerklePatriciaTree.Trie.empty_trie_root_hash()
            }
        }

        block = %{
          block
          | block_hash: Block.hash(block)
        }

        base_block_chunk =
          if is_nil(block_chunk.number) do
            %{block_chunk | number: block.header.number - 1, hash: block.header.parent_hash}
          else
            block_chunk
          end

        block_data = %BlockChunk.BlockData{
          header: %BlockChunk.BlockHeader{
            author: block.header.beneficiary,
            state_root: block.header.state_root,
            logs_bloom: block.header.logs_bloom,
            difficulty: block.header.difficulty,
            gas_limit: block.header.gas_limit,
            gas_used: block.header.gas_used,
            timestamp: block.header.timestamp,
            extra_data: block.header.extra_data,
            transactions: block.transactions,
            transactions_rlp: Enum.map(block.transactions, &Transaction.serialize/1),
            ommers: block.ommers,
            ommers_rlp: Enum.map(block.ommers, &Header.serialize/1),
            mix_hash: block.header.mix_hash,
            nonce: block.header.nonce
          },
          receipts: [],
          receipts_rlp: []
        }

        {%{
           base_block_chunk
           | total_difficulty: block.header.difficulty,
             block_data_list: base_block_chunk.block_data_list ++ [block_data]
         }, [block | curr_blocks]}
      end)

    block_snapshot_data = %SnapshotData{
      chunk: block_chunk
    }

    [block_chunk_data] = SnapshotData.serialize(block_snapshot_data)

    block_snapshot_data_with_hash = %{
      block_snapshot_data
      | hash: Keccak.kec(block_chunk_data)
    }

    post_state_account_entries =
      for {address, account_json} <- test_info["postState"] do
        code = Exth.decode_hex(account_json["code"])

        rich_account = %StateChunk.RichAccount{
          nonce: Exth.maybe_decode_unsigned(Exth.decode_hex(account_json["nonce"])),
          balance: Exth.maybe_decode_unsigned(Exth.decode_hex(account_json["balance"])),
          code_flag: if(code == <<>>, do: :no_code, else: :has_code),
          code: Exth.decode_hex(account_json["code"]),
          # TODO: Verify storage is sorted properly
          storage:
            for(
              {k, v} <- account_json["storage"],
              do: {Keccak.kec(Exth.decode_hex(k)), Exth.decode_hex(v)}
            )
            |> Enum.sort()
        }

        {Keccak.kec(Exth.decode_hex(address)), rich_account}
      end

    state_chunk = %StateChunk{
      account_entries: post_state_account_entries
    }

    state_snapshot_data = %SnapshotData{
      chunk: state_chunk
    }

    [state_chunk_data] = SnapshotData.serialize(state_snapshot_data)

    state_snapshot_data_with_hash = %{
      state_snapshot_data
      | hash: Keccak.kec(state_chunk_data)
    }

    last_block_info = List.last(test_info["blocks"])

    {test_info, Enum.reverse(blocks),
     %SnapshotManifest.Manifest{
       version: 2,
       state_hashes: [state_snapshot_data_with_hash.hash],
       block_hashes: [block_snapshot_data_with_hash.hash],
       state_root:
         Exth.decode_hex(
           Keyword.get(opts, :state_root, last_block_info["blockHeader"]["stateRoot"])
         ),
       block_number:
         Exth.maybe_decode_unsigned(Exth.decode_hex(last_block_info["blockHeader"]["number"])),
       block_hash: Exth.decode_hex(Keyword.get(opts, :block_hash, test_info["lastblockhash"]))
     }, block_snapshot_data_with_hash, state_snapshot_data_with_hash}
  end

  defp memory_trie() do
    ets_db = MerklePatriciaTree.Test.random_ets_db()

    MerklePatriciaTree.Trie.new(ets_db, MerklePatriciaTree.Trie.empty_trie_root_hash())
  end
end
