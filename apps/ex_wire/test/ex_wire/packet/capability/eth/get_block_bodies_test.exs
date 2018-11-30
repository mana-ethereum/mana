defmodule ExWire.Packet.Capability.Eth.GetBlockBodiesTest do
  use ExUnit.Case, async: true
  doctest ExWire.Packet.Capability.Eth.GetBlockBodies

  alias Block.Header
  alias Blockchain.Transaction
  alias ExWire.BridgeSyncMock
  alias ExWire.Packet.Capability.Eth.BlockBodies
  alias ExWire.Packet.Capability.Eth.GetBlockBodies
  alias ExWire.Struct.Block
  alias MerklePatriciaTree.Trie

  describe "handle/1" do
    test "bodies not found test" do
      result =
        %GetBlockBodies{hashes: [<<5>>, <<6>>]}
        |> GetBlockBodies.handle()

      assert result == {:send, %BlockBodies{blocks: []}}
    end

    test "body found test" do
      BridgeSyncMock.start_link(%{})
      db = MerklePatriciaTree.Test.random_ets_db()
      trie = db |> Trie.new()

      block = %Blockchain.Block{
        transactions: [
          %Transaction{
            nonce: 5,
            gas_price: 6,
            gas_limit: 7,
            to: <<1::160>>,
            value: 8,
            v: 27,
            r: 9,
            s: 10,
            data: "hi"
          }
        ],
        header: %Header{
          number: 5,
          parent_hash: <<1, 2, 3>>,
          beneficiary: <<2, 3, 4>>,
          difficulty: 100,
          timestamp: 11,
          mix_hash: <<1>>,
          nonce: <<2>>
        }
      }

      Blockchain.Block.put_block(block, trie)
      BridgeSyncMock.set_current_trie(trie)
      block_struct = Block.new(block)

      result =
        %GetBlockBodies{hashes: [block |> Blockchain.Block.hash()]}
        |> GetBlockBodies.handle()

      assert result == {:send, %BlockBodies{blocks: [block_struct]}}
    end
  end
end
