defmodule ExWire.Packet.Capability.Eth.GetReceiptsTest do
  use ExUnit.Case, async: true
  doctest ExWire.Packet.Capability.Eth.GetReceipts

  alias Blockchain.Transaction.Receipt

  describe "handle/1" do
    test "respond to request" do
      ExWire.BridgeSyncMock.start_link(%{})

      receipt = %Receipt{
        state: <<1, 2, 3>>,
        cumulative_gas: 5,
        bloom_filter: <<2, 3, 4>>,
        logs: []
      }

      receipt_rlp_bin =
        receipt
        |> Receipt.serialize()
        |> ExRLP.encode()

      MerklePatriciaTree.Test.random_ets_db()
      |> MerklePatriciaTree.Trie.new()
      |> MerklePatriciaTree.TrieStorage.put_raw_key!(<<2::256>>, receipt_rlp_bin)
      |> ExWire.BridgeSyncMock.set_current_trie()

      handle_response =
        %ExWire.Packet.Capability.Eth.GetReceipts{hashes: [<<1::256>>, <<2::256>>]}
        |> ExWire.Packet.Capability.Eth.GetReceipts.handle()

      assert handle_response ==
               {:send,
                %ExWire.Packet.Capability.Eth.Receipts{
                  receipts: [receipt]
                }}
    end
  end
end
