defmodule ExWire.Sync.WarpProcessor.PowProcessorTest do
  use ExUnit.Case, async: true
  alias Block.Header
  alias Blockchain.{Account, Block, Transaction}
  alias Blockchain.Transaction.Receipt
  alias ExthCrypto.Hash.Keccak
  alias ExWire.Packet.Capability.Par.SnapshotData.{BlockChunk, StateChunk}
  alias ExWire.Sync.WarpProcessor.PowProcessor
  alias MerklePatriciaTree.{Trie, TrieStorage}
  doctest PowProcessor

  @empty_trie Trie.empty_trie_root_hash()

  describe "#process_block_chunk/2" do
    trie =
      MerklePatriciaTree.Test.random_ets_db()
      |> Trie.new()

    block_data_1 = %BlockChunk.BlockData{
      header: %BlockChunk.BlockHeader{
        author: <<1::160>>,
        state_root: <<2::256>>,
        logs_bloom: <<3::2048>>,
        difficulty: 1_000_000,
        gas_limit: 6_000_000,
        gas_used: 10_000,
        timestamp: 123_456_789,
        extra_data: "cool!",
        transactions: [],
        transactions_rlp: [],
        ommers: [],
        ommers_rlp: [],
        mix_hash: <<10::256>>,
        nonce: <<11::64>>
      },
      receipts: [],
      receipts_rlp: []
    }

    block_data_2 = %BlockChunk.BlockData{
      header: %BlockChunk.BlockHeader{
        author: <<2::160>>,
        state_root: <<3::256>>,
        logs_bloom: <<4::2048>>,
        difficulty: 1_000_001,
        gas_limit: 6_000_000,
        gas_used: 20_000,
        timestamp: 123_456_789,
        extra_data: "cool 2x!",
        transactions: [],
        transactions_rlp: [],
        ommers: [],
        ommers_rlp: [],
        mix_hash: <<10::256>>,
        nonce: <<11::64>>
      },
      receipts: [],
      receipts_rlp: []
    }

    block_chunk = %BlockChunk{
      number: 500,
      hash: <<55::256>>,
      total_difficulty: 1_000_001,
      block_data_list: [
        block_data_1,
        block_data_2
      ]
    }

    assert {processed_blocks, block, next_trie} =
             PowProcessor.process_block_chunk(block_chunk, trie)

    assert processed_blocks == MapSet.new([501, 502])
    assert block.header.number == 502
  end

  describe "#process_state_chunk/2" do
    test "properly handles multiple accounts" do
      trie =
        MerklePatriciaTree.Test.random_ets_db()
        |> Trie.new()

      state_chunk = %StateChunk{
        account_entries: [
          {<<1::256>>,
           %StateChunk.RichAccount{
             nonce: 1,
             balance: 1,
             code_flag: :no_code,
             code: <<>>,
             storage: [{<<1::256>>, <<1::256>>}]
           }},
          {<<2::256>>,
           %StateChunk.RichAccount{
             nonce: 2,
             balance: 2,
             code_flag: :no_code,
             code: <<>>,
             storage: [{<<2::256>>, <<2::256>>}]
           }},
          {<<3::256>>,
           %StateChunk.RichAccount{
             nonce: 3,
             balance: 3,
             code_flag: :no_code,
             code: <<>>,
             storage: [{<<3::256>>, <<3::256>>}]
           }}
        ]
      }

      assert {[
                {<<1::256>>, _account_1_rlp, [{<<1::256>>, <<1::256>>}]},
                {<<2::256>>, _account_2_rlp, nil},
                {<<3::256>>, _account_3_rlp, [{<<3::256>>, <<3::256>>}]}
              ], _} = PowProcessor.process_state_chunk(state_chunk, trie)
    end
  end

  describe "#process_block/5" do
    test "given a block data, returns a proper block saved to the trie" do
      trie =
        MerklePatriciaTree.Test.random_ets_db()
        |> Trie.new()

      transactions = [
        transaction = %Transaction{
          nonce: 1,
          gas_price: 2,
          gas_limit: 3,
          to: <<4::160>>,
          value: 5,
          v: 6,
          r: 7,
          s: 1,
          init: <<>>,
          data: <<5::256, 6::256>>
        }
      ]

      receipts = [
        receipt = %Receipt{
          state: <<12::256>>,
          cumulative_gas: 20,
          bloom_filter: <<13::2048>>,
          logs: []
        }
      ]

      ommers = [
        %Header{
          parent_hash: <<20::256>>,
          ommers_hash: Keccak.kec(<<>>),
          beneficiary: <<21::160>>,
          state_root: <<22::256>>,
          transactions_root: <<23::256>>,
          receipts_root: <<24::256>>,
          logs_bloom: <<25::2048>>,
          difficulty: 200,
          number: 201,
          gas_limit: 202,
          gas_used: 203,
          timestamp: 204,
          extra_data: <<>>,
          mix_hash: <<0::256>>,
          nonce: <<0::64>>
        }
      ]

      block_data = %BlockChunk.BlockData{
        header: %BlockChunk.BlockHeader{
          author: <<1::160>>,
          state_root: <<2::256>>,
          logs_bloom: <<3::2048>>,
          difficulty: 1_000_000,
          gas_limit: 6_000_000,
          gas_used: 10_000,
          timestamp: 123_456_789,
          extra_data: "cool!",
          transactions: transactions,
          transactions_rlp: Enum.map(transactions, &Transaction.serialize/1),
          ommers: ommers,
          ommers_rlp: Enum.map(ommers, &Header.serialize/1),
          mix_hash: <<10::256>>,
          nonce: <<11::64>>
        },
        receipts: receipts,
        receipts_rlp: Enum.map(receipts, &Receipt.serialize/1)
      }

      assert {next_trie, block} = PowProcessor.process_block(block_data, <<255::256>>, 201, trie)

      # Make sure the block matches expectations
      assert block == %Block{
               block_hash:
                 <<231, 180, 221, 248, 0, 10, 93, 194, 91, 102, 211, 37, 84, 232, 227, 204, 125,
                   141, 30, 203, 183, 32, 105, 25, 15, 139, 192, 116, 160, 126, 146, 153>>,
               header: %Header{
                 parent_hash: <<255::256>>,
                 ommers_hash:
                   <<85, 56, 57, 222, 127, 245, 151, 250, 92, 28, 22, 12, 0, 242, 175, 102, 156,
                     229, 75, 117, 156, 172, 159, 12, 254, 233, 104, 52, 45, 16, 153, 110>>,
                 beneficiary: <<1::160>>,
                 state_root: <<2::256>>,
                 transactions_root:
                   <<142, 251, 208, 146, 224, 3, 149, 181, 212, 219, 38, 154, 87, 163, 69, 192,
                     25, 172, 144, 160, 89, 253, 8, 145, 206, 166, 219, 98, 4, 237, 20, 22>>,
                 receipts_root:
                   <<11, 58, 57, 115, 68, 41, 47, 58, 109, 82, 159, 87, 205, 177, 44, 90, 21, 244,
                     132, 108, 152, 90, 55, 125, 62, 10, 149, 27, 132, 51, 51, 168>>,
                 logs_bloom: <<3::2048>>,
                 difficulty: 1_000_000,
                 number: 201,
                 gas_limit: 6_000_000,
                 gas_used: 10_000,
                 timestamp: 123_456_789,
                 extra_data: "cool!",
                 mix_hash: <<10::256>>,
                 nonce: <<11::64>>
               },
               transactions: transactions,
               receipts: receipts,
               ommers: ommers
             }

      # Next, let's check that our trie has all the right data
      assert Block.get_block(block.block_hash, next_trie) ==
               {:ok, %{block | receipts: [], block_hash: nil}}

      assert Block.get_transaction(block, 0, next_trie.db) == transaction
      assert Block.get_transaction(block, 1, next_trie.db) == nil

      assert Block.get_receipt(block, 0, next_trie.db) == receipt
      assert Block.get_receipt(block, 1, next_trie.db) == nil
    end
  end

  describe "#process_account/4" do
    test "properly handles account with no code" do
      trie =
        MerklePatriciaTree.Test.random_ets_db()
        |> Trie.new()

      rich_account = %StateChunk.RichAccount{
        nonce: 1,
        balance: 1,
        code_flag: :no_code,
        code: <<>>,
        storage: [{<<1::256>>, <<1::256>>}]
      }

      assert {_, {<<1::256>>, account_rlp, storage}} =
               PowProcessor.process_account(<<1::256>>, rich_account, trie, true)

      {_, expected_storage_root} =
        process_account_storage(
          [{<<1::256>>, <<1::256>>}],
          trie,
          @empty_trie
        )

      assert Account.deserialize(ExRLP.decode(account_rlp)) == %Account{
               nonce: 1,
               balance: 1,
               code_hash: Keccak.kec(<<>>),
               storage_root: expected_storage_root
             }

      assert storage == [{<<1::256>>, <<1::256>>}]
    end

    test "properly handles account with code" do
      trie =
        MerklePatriciaTree.Test.random_ets_db()
        |> Trie.new()

      rich_account = %StateChunk.RichAccount{
        nonce: 1,
        balance: 1,
        code_flag: :has_code,
        code: "code",
        storage: [{<<1::256>>, <<1::256>>}]
      }

      assert {new_trie, {<<1::256>>, account_rlp, storage}} =
               PowProcessor.process_account(<<1::256>>, rich_account, trie, true)

      assert Trie.get_raw_key(new_trie, Keccak.kec("code")) == {:ok, "code"}

      {_, expected_storage_root} =
        process_account_storage(
          [{<<1::256>>, <<1::256>>}],
          trie,
          @empty_trie
        )

      assert Account.deserialize(ExRLP.decode(account_rlp)) == %Account{
               nonce: 1,
               balance: 1,
               code_hash: Keccak.kec("code"),
               storage_root: expected_storage_root
             }

      assert storage == [{<<1::256>>, <<1::256>>}]
    end

    test "properly handles account with repeat code" do
      trie =
        MerklePatriciaTree.Test.random_ets_db()
        |> Trie.new()

      rich_account = %StateChunk.RichAccount{
        nonce: 1,
        balance: 1,
        code_flag: :has_repeat_code,
        code: Keccak.kec("code"),
        storage: [{<<1::256>>, <<1::256>>}]
      }

      assert {new_trie, {<<1::256>>, account_rlp, storage}} =
               PowProcessor.process_account(<<1::256>>, rich_account, trie, true)

      assert Trie.get_raw_key(new_trie, Keccak.kec("code")) == :not_found

      {_, expected_storage_root} =
        process_account_storage(
          [{<<1::256>>, <<1::256>>}],
          trie,
          @empty_trie
        )

      assert Account.deserialize(ExRLP.decode(account_rlp)) == %Account{
               nonce: 1,
               balance: 1,
               code_hash: Keccak.kec("code"),
               storage_root: expected_storage_root
             }

      assert storage == [{<<1::256>>, <<1::256>>}]
    end

    test "properly handles account with keep storage set to false" do
      trie =
        MerklePatriciaTree.Test.random_ets_db()
        |> Trie.new()

      rich_account = %StateChunk.RichAccount{
        nonce: 1,
        balance: 1,
        code_flag: :has_repeat_code,
        code: Keccak.kec("code"),
        storage: [{<<1::256>>, <<1::256>>}]
      }

      assert {new_trie, {<<1::256>>, account_rlp, nil}} =
               PowProcessor.process_account(<<1::256>>, rich_account, trie, false)

      assert Trie.get_raw_key(new_trie, Keccak.kec("code")) == :not_found

      {_, expected_storage_root} =
        process_account_storage(
          [{<<1::256>>, <<1::256>>}],
          trie,
          @empty_trie
        )

      assert Account.deserialize(ExRLP.decode(account_rlp)) == %Account{
               nonce: 1,
               balance: 1,
               code_hash: Keccak.kec("code"),
               storage_root: expected_storage_root
             }
    end
  end

  describe "#process_account_states/2" do
    setup do
      trie =
        MerklePatriciaTree.Test.random_ets_db()
        |> Trie.new()

      blank_account =
        %Account{}
        |> Account.serialize()
        |> ExRLP.encode()

      first_storage = [{<<1::256>>, <<10::256>>}]
      second_storage = [{<<2::256>>, <<10::256>>}]

      {trie, root_hash_first} = process_account_storage(first_storage, trie, @empty_trie)

      {trie, root_hash_second} = process_account_storage(second_storage, trie, @empty_trie)

      first_account =
        %Account{storage_root: root_hash_first}
        |> Account.serialize()
        |> ExRLP.encode()

      second_account =
        %Account{storage_root: root_hash_second}
        |> Account.serialize()
        |> ExRLP.encode()

      {:ok,
       %{
         trie: trie,
         blank_account: blank_account,
         first_storage: first_storage,
         second_storage: second_storage,
         first_account: first_account,
         second_account: second_account
       }}
    end

    test "returns correct state trie for simple accounts", %{
      trie: trie,
      blank_account: blank_account
    } do
      account_states = [
        {<<1::256>>, blank_account, nil},
        {<<2::256>>, blank_account, nil}
      ]

      more_account_states = [
        {<<3::256>>, blank_account, nil},
        {<<4::256>>, blank_account, nil}
      ]

      next_trie = PowProcessor.process_account_states(account_states, trie)

      assert Exth.encode_hex(TrieStorage.root_hash(next_trie)) ==
               "0x643dbbff270e2938cf0876a8ba59cd03fb148da2ea49e34ea38697e42cbe143d"

      # Encode again and verify returns the same hash
      next_trie_2 = PowProcessor.process_account_states(account_states, trie)

      assert Exth.encode_hex(TrieStorage.root_hash(next_trie_2)) ==
               "0x643dbbff270e2938cf0876a8ba59cd03fb148da2ea49e34ea38697e42cbe143d"

      # Reverse the order and encode and check returns the same hash
      next_trie_3 = PowProcessor.process_account_states(Enum.reverse(account_states), trie)

      assert Exth.encode_hex(TrieStorage.root_hash(next_trie_3)) ==
               "0x643dbbff270e2938cf0876a8ba59cd03fb148da2ea49e34ea38697e42cbe143d"

      # Run the accounts again on a previous trie and verify returns the same hash
      next_trie_4 = PowProcessor.process_account_states(account_states, next_trie)

      assert Exth.encode_hex(TrieStorage.root_hash(next_trie_4)) ==
               "0x643dbbff270e2938cf0876a8ba59cd03fb148da2ea49e34ea38697e42cbe143d"

      # Run the other account states
      next_trie_5 = PowProcessor.process_account_states(more_account_states, next_trie)

      assert Exth.encode_hex(TrieStorage.root_hash(next_trie_5)) ==
               "0x1e0dd79b3c5b712562afa8033232817255e97f30afe80c09467dc5bd16b860f8"

      # The run in the other order
      next_trie_6 = PowProcessor.process_account_states(more_account_states, trie)

      assert Exth.encode_hex(TrieStorage.root_hash(next_trie_6)) ==
               "0x89b4a683f0769508747afb2a8452b349659fc500c86e323b493711e1e358b04d"

      next_trie_7 = PowProcessor.process_account_states(account_states, next_trie_6)

      # This should match next_trie_5
      assert Exth.encode_hex(TrieStorage.root_hash(next_trie_7)) ==
               "0x1e0dd79b3c5b712562afa8033232817255e97f30afe80c09467dc5bd16b860f8"
    end

    test "returns correct state trie with existing account", %{
      trie: trie,
      blank_account: blank_account,
      first_account: first_account,
      first_storage: first_storage,
      second_account: second_account,
      second_storage: second_storage
    } do
      account_states = [
        {<<1::256>>, blank_account, nil},
        {<<2::256>>, first_account, first_storage}
      ]

      more_account_states = [
        {<<2::256>>, second_account, second_storage},
        {<<3::256>>, blank_account, nil}
      ]

      # First, run account states
      next_trie = PowProcessor.process_account_states(account_states, trie)

      assert Exth.encode_hex(TrieStorage.root_hash(next_trie)) ==
               "0x526935838f9214110c1b1afc3c334877d0536b985bdb8f2afd490c8431a267e2"

      # Then run more_account_states on top
      next_trie_2 = PowProcessor.process_account_states(more_account_states, next_trie)

      assert Exth.encode_hex(TrieStorage.root_hash(next_trie_2)) ==
               "0x752d3962560c5f78ddd6266d4ce78ff8771281fb6f3924f5c18fbc9c5cc0a2ca"

      # Now, run more account states
      next_trie_3 = PowProcessor.process_account_states(more_account_states, trie)

      assert Exth.encode_hex(TrieStorage.root_hash(next_trie_3)) ==
               "0xf619e70caa1e2b60bd68f52d37e64682c13f9145307026b363cabe56db123e46"

      # Then run account_states on top
      next_trie_4 = PowProcessor.process_account_states(account_states, next_trie_3)

      assert Exth.encode_hex(TrieStorage.root_hash(next_trie_4)) ==
               "0x752d3962560c5f78ddd6266d4ce78ff8771281fb6f3924f5c18fbc9c5cc0a2ca"
    end

    test "ignores existing accounts if storage not included", %{
      trie: trie,
      blank_account: blank_account,
      second_account: second_account,
      second_storage: second_storage
    } do
      account_states = [
        {<<1::256>>, blank_account, nil}
      ]

      more_account_states = [
        {<<2::256>>, second_account, second_storage},
        {<<3::256>>, blank_account, nil}
      ]

      # First, run account states
      next_trie = PowProcessor.process_account_states(account_states, trie)

      assert Exth.encode_hex(TrieStorage.root_hash(next_trie)) ==
               "0x69b5c560f84dde1ecb0584976f4ebbe78e34bb6f32410777309a8693424bb563"

      # Then run more_account_states on top
      next_trie_2 = PowProcessor.process_account_states(more_account_states, next_trie)

      assert Exth.encode_hex(TrieStorage.root_hash(next_trie_2)) ==
               "0x2eabd1076c70e6a47969dd85b586a1cacfa922cd1ba6d705dc90c8525df69159"

      # Now, run more account states
      next_trie_3 = PowProcessor.process_account_states(more_account_states, trie)

      assert Exth.encode_hex(TrieStorage.root_hash(next_trie_3)) ==
               "0xf619e70caa1e2b60bd68f52d37e64682c13f9145307026b363cabe56db123e46"

      # Then run account_states on top
      next_trie_4 = PowProcessor.process_account_states(account_states, next_trie_3)

      assert Exth.encode_hex(TrieStorage.root_hash(next_trie_4)) ==
               "0x2eabd1076c70e6a47969dd85b586a1cacfa922cd1ba6d705dc90c8525df69159"
    end
  end

  defp process_account_storage(storage, trie, root_hash) do
    Enum.reduce(storage, {trie, root_hash}, fn {k, v}, {curr_trie, curr_root} ->
      {subtrie, updated_trie} = TrieStorage.update_subtrie_key(curr_trie, curr_root, k, v)

      updated_root_hash = TrieStorage.root_hash(subtrie)

      {updated_trie, updated_root_hash}
    end)
  end
end
