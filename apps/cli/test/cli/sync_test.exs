defmodule CLI.SyncTest do
  use ExUnit.Case, async: true
  alias CLI.Sync
  doctest Sync

  alias Blockchain.{Blocktree, Chain}
  alias CLI.BlockProvider.RPC
  alias CLI.MockHttpClient
  alias MerklePatriciaTree.DB.ETS

  describe "sync_new_blocks/6" do
    test "it pulls a new block and adds it to chain" do
      trie =
        :sync_new_blocks_test_0
        |> ETS.init()
        |> MerklePatriciaTree.Trie.new()

      chain = Chain.load_chain(:ropsten)
      blocktree = Blocktree.new_tree()

      assert Sync.sync_new_blocks(
               RPC,
               MockHttpClient,
               trie,
               chain,
               blocktree,
               0,
               2,
               2
             ) ==
               {:ok,
                %Blockchain.Blocktree{
                  best_block: %Blockchain.Block{
                    block_hash:
                      <<65, 128, 11, 92, 63, 23, 23, 104, 125, 133, 252, 144, 24, 250, 172, 10,
                        110, 144, 179, 157, 234, 160, 185, 158, 127, 228, 254, 121, 109, 222, 178,
                        106>>,
                    header: %Block.Header{
                      beneficiary:
                        <<209, 174, 180, 40, 133, 164, 59, 114, 181, 24, 24, 46, 248, 147, 18, 88,
                          20, 129, 16, 72>>,
                      difficulty: 997_888,
                      extra_data:
                        <<216, 131, 1, 5, 3, 132, 103, 101, 116, 104, 135, 103, 111, 49, 46, 55,
                          46, 49, 134, 100, 97, 114, 119, 105, 110>>,
                      gas_limit: 16_760_833,
                      gas_used: 0,
                      logs_bloom: <<0::2048>>,
                      mix_hash:
                        <<15, 152, 177, 95, 26, 73, 1, 167, 233, 32, 79, 60, 80, 10, 123, 213, 39,
                          179, 251, 44, 51, 64, 225, 33, 118, 164, 75, 131, 228, 20, 166, 158>>,
                      nonce: <<14, 206, 8, 234, 140, 73, 223, 217>>,
                      number: 1,
                      ommers_hash:
                        <<29, 204, 77, 232, 222, 199, 93, 122, 171, 133, 181, 103, 182, 204, 212,
                          26, 211, 18, 69, 27, 148, 138, 116, 19, 240, 161, 66, 253, 64, 212, 147,
                          71>>,
                      parent_hash:
                        <<65, 148, 16, 35, 104, 9, 35, 224, 254, 77, 116, 163, 75, 218, 200, 20,
                          31, 37, 64, 227, 174, 144, 98, 55, 24, 228, 125, 102, 209, 202, 74,
                          45>>,
                      receipts_root:
                        <<86, 232, 31, 23, 27, 204, 85, 166, 255, 131, 69, 230, 146, 192, 248,
                          110, 91, 72, 224, 27, 153, 108, 173, 192, 1, 98, 47, 181, 227, 99, 180,
                          33>>,
                      state_root:
                        <<199, 176, 16, 7, 161, 13, 160, 69, 234, 203, 144, 56, 88, 135, 221, 12,
                          56, 252, 181, 219, 115, 147, 0, 107, 221, 226, 75, 147, 135, 60, 51,
                          75>>,
                      timestamp: 1_479_642_530,
                      transactions_root:
                        <<86, 232, 31, 23, 27, 204, 85, 166, 255, 131, 69, 230, 146, 192, 248,
                          110, 91, 72, 224, 27, 153, 108, 173, 192, 1, 98, 47, 181, 227, 99, 180,
                          33>>
                    },
                    ommers: [],
                    receipts: [],
                    transactions: []
                  }
                }}
    end

    test "fails when it cannot pull a block" do
      trie =
        :sync_new_blocks_test_1
        |> ETS.init()
        |> MerklePatriciaTree.Trie.new()

      chain = Chain.load_chain(:ropsten)
      blocktree = Blocktree.new_tree()

      assert Sync.sync_new_blocks(
               RPC,
               MockHttpClient,
               trie,
               chain,
               blocktree,
               0,
               3,
               2
             ) == {:error, "MockClient: failed to get block 2"}
    end
  end
end
