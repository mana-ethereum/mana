defmodule Blockchain.GenesisTest do
  use ExUnit.Case

  doctest Blockchain.Genesis

  alias EthCore.Block.Header
  alias Blockchain.{Genesis, Block, Chain}

  describe "create_block/2" do
    test "uses a genesis chain spec to create a new block" do
      db = MerklePatriciaTree.Test.random_ets_db()
      chain = Chain.load_chain(:ropsten)

      expected = %Block{
        header: %Header{
          number: 0,
          timestamp: 0,
          beneficiary: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
          difficulty: 1_048_576,
          extra_data: "55555555555555555555555555555555",
          gas_limit: 16_777_216,
          parent_hash:
            <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
              0, 0, 0, 0>>,
          state_root:
            <<33, 123, 11, 188, 251, 114, 226, 213, 126, 40, 243, 60, 179, 97, 185, 152, 53, 19,
              23, 119, 85, 220, 63, 51, 206, 62, 112, 34, 237, 98, 183, 123>>,
          transactions_root:
            <<86, 232, 31, 23, 27, 204, 85, 166, 255, 131, 69, 230, 146, 192, 248, 110, 91, 72,
              224, 27, 153, 108, 173, 192, 1, 98, 47, 181, 227, 99, 180, 33>>,
          receipts_root:
            <<86, 232, 31, 23, 27, 204, 85, 166, 255, 131, 69, 230, 146, 192, 248, 110, 91, 72,
              224, 27, 153, 108, 173, 192, 1, 98, 47, 181, 227, 99, 180, 33>>,
          ommers_hash:
            <<29, 204, 77, 232, 222, 199, 93, 122, 171, 133, 181, 103, 182, 204, 212, 26, 211, 18,
              69, 27, 148, 138, 116, 19, 240, 161, 66, 253, 64, 212, 147, 71>>
        },
        ommers: [],
        transactions: []
      }

      assert Genesis.new_block(chain, db) == expected
    end

    # TODO: Add test case with initial storage
  end
end
