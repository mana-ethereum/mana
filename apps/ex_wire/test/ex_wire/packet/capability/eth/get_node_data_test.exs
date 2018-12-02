defmodule ExWire.Packet.Capability.Eth.GetNodeDataTest do
  use ExUnit.Case, async: true
  doctest ExWire.Packet.Capability.Eth.GetNodeData

  describe "handle/1" do
    test "responds to request" do
      ExWire.BridgeSyncMock.start_link(%{})

      MerklePatriciaTree.Test.random_ets_db()
      |> MerklePatriciaTree.Trie.new()
      |> MerklePatriciaTree.TrieStorage.put_raw_key!(<<2::256>>, "mana")
      |> ExWire.BridgeSyncMock.set_current_trie()

      handle_response =
        %ExWire.Packet.Capability.Eth.GetNodeData{hashes: [<<1::256>>, <<2::256>>]}
        |> ExWire.Packet.Capability.Eth.GetNodeData.handle()

      assert handle_response ==
               {:send,
                %ExWire.Packet.Capability.Eth.NodeData{
                  values: ["mana"]
                }}
    end
  end
end
