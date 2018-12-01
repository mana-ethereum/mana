defmodule ExWire.Packet.Capability.Eth.StatusTest do
  use ExUnit.Case, async: true
  doctest ExWire.Packet.Capability.Eth.Status

  describe "handle/0" do
    test "peer with incompatible version" do
      result =
        %ExWire.Packet.Capability.Eth.Status{
          protocol_version: 555,
          network_id: 3,
          total_difficulty: 10,
          best_hash: <<5>>,
          genesis_hash: <<4>>
        }
        |> ExWire.Packet.Capability.Eth.Status.handle()

      assert result == {:disconnect, :useless_peer}
    end

    test "sync not running, can't load chain, return default" do
      # Test when Sync is not running -- should just parrot the packet
      result =
        %ExWire.Packet.Capability.Eth.Status{
          protocol_version: 63,
          network_id: 30,
          total_difficulty: 10,
          best_hash: <<5>>,
          genesis_hash: <<4>>
        }
        |> ExWire.Packet.Capability.Eth.Status.handle()

      assert result ==
               {:send,
                %ExWire.Packet.Capability.Eth.Status{
                  best_hash: <<4>>,
                  genesis_hash: <<4>>,
                  network_id: 3,
                  protocol_version: 63,
                  total_difficulty: 10
                }}
    end

    test "" do
      ExWire.BridgeSyncMock.start_link(%{})
      best_block = %Blockchain.Block{block_hash: <<6>>, header: %Block.Header{difficulty: 100}}
      ExWire.BridgeSyncMock.set_best_block(best_block)
      genesis_hash = <<0::256>>
      ExWire.BridgeSyncMock.set_chain(%Blockchain.Chain{genesis: %{parent_hash: genesis_hash}})

      result =
        %ExWire.Packet.Capability.Eth.Status{
          protocol_version: 63,
          network_id: 3,
          total_difficulty: 10,
          best_hash: <<5>>,
          genesis_hash: <<4>>
        }
        |> ExWire.Packet.Capability.Eth.Status.handle()

      assert result ==
               {:send,
                %ExWire.Packet.Capability.Eth.Status{
                  genesis_hash: genesis_hash,
                  best_hash: best_block.block_hash,
                  network_id: 3,
                  protocol_version: 63,
                  total_difficulty: best_block.header.difficulty
                }}
    end
  end
end
