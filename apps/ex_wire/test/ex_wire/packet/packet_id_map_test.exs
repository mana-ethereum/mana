defmodule ExWire.Packet.PacketIdMapTest do
  use ExUnit.Case, async: true
  doctest ExWire.Packet.PacketIdMap

  describe "default_map/0" do
    test "Call" do
      map = ExWire.Packet.PacketIdMap.default_map()

      assert map == %ExWire.Packet.PacketIdMap{
               ids_to_modules: %{
                 0x00 => ExWire.Packet.Protocol.Hello,
                 0x01 => ExWire.Packet.Protocol.Disconnect,
                 0x02 => ExWire.Packet.Protocol.Ping,
                 0x03 => ExWire.Packet.Protocol.Pong
               },
               modules_to_ids: %{
                 ExWire.Packet.Protocol.Hello => 0x00,
                 ExWire.Packet.Protocol.Disconnect => 0x01,
                 ExWire.Packet.Protocol.Ping => 0x02,
                 ExWire.Packet.Protocol.Pong => 0x03
               }
             }
    end
  end

  describe "new/1" do
    test "Empty Map" do
      map1 = ExWire.Packet.PacketIdMap.new()
      map2 = ExWire.Packet.PacketIdMap.new([])

      assert map1 == map2 &&
               map2 == %ExWire.Packet.PacketIdMap{
                 ids_to_modules: %{
                   0x00 => ExWire.Packet.Protocol.Hello,
                   0x01 => ExWire.Packet.Protocol.Disconnect,
                   0x02 => ExWire.Packet.Protocol.Ping,
                   0x03 => ExWire.Packet.Protocol.Pong
                 },
                 modules_to_ids: %{
                   ExWire.Packet.Protocol.Hello => 0x00,
                   ExWire.Packet.Protocol.Disconnect => 0x01,
                   ExWire.Packet.Protocol.Ping => 0x02,
                   ExWire.Packet.Protocol.Pong => 0x03
                 }
               }
    end

    test "Invalid Capabilities" do
      map =
        ExWire.Packet.PacketIdMap.new([
          ExWire.Packet.Capability.new({:derp, 1}),
          ExWire.Packet.Capability.new({:eth, 60})
        ])

      assert map == %ExWire.Packet.PacketIdMap{
               ids_to_modules: %{
                 0x00 => ExWire.Packet.Protocol.Hello,
                 0x01 => ExWire.Packet.Protocol.Disconnect,
                 0x02 => ExWire.Packet.Protocol.Ping,
                 0x03 => ExWire.Packet.Protocol.Pong
               },
               modules_to_ids: %{
                 ExWire.Packet.Protocol.Hello => 0x00,
                 ExWire.Packet.Protocol.Disconnect => 0x01,
                 ExWire.Packet.Protocol.Ping => 0x02,
                 ExWire.Packet.Protocol.Pong => 0x03
               }
             }
    end

    test "Valid Capability" do
      map = ExWire.Packet.PacketIdMap.new([ExWire.Packet.Capability.new({:eth, 62})])

      assert map == %ExWire.Packet.PacketIdMap{
               ids_to_modules: %{
                 0x00 => ExWire.Packet.Protocol.Hello,
                 0x01 => ExWire.Packet.Protocol.Disconnect,
                 0x02 => ExWire.Packet.Protocol.Ping,
                 0x03 => ExWire.Packet.Protocol.Pong,
                 0x10 => ExWire.Packet.Capability.Eth.Status,
                 0x11 => ExWire.Packet.Capability.Eth.NewBlockHashes,
                 0x12 => ExWire.Packet.Capability.Eth.Transactions,
                 0x13 => ExWire.Packet.Capability.Eth.GetBlockHeaders,
                 0x14 => ExWire.Packet.Capability.Eth.BlockHeaders,
                 0x15 => ExWire.Packet.Capability.Eth.GetBlockBodies,
                 0x16 => ExWire.Packet.Capability.Eth.BlockBodies,
                 0x17 => ExWire.Packet.Capability.Eth.NewBlock
               },
               modules_to_ids: %{
                 ExWire.Packet.Protocol.Hello => 0x00,
                 ExWire.Packet.Protocol.Disconnect => 0x01,
                 ExWire.Packet.Protocol.Ping => 0x02,
                 ExWire.Packet.Protocol.Pong => 0x03,
                 ExWire.Packet.Capability.Eth.Status => 0x10,
                 ExWire.Packet.Capability.Eth.NewBlockHashes => 0x11,
                 ExWire.Packet.Capability.Eth.Transactions => 0x12,
                 ExWire.Packet.Capability.Eth.GetBlockHeaders => 0x13,
                 ExWire.Packet.Capability.Eth.BlockHeaders => 0x14,
                 ExWire.Packet.Capability.Eth.GetBlockBodies => 0x15,
                 ExWire.Packet.Capability.Eth.BlockBodies => 0x16,
                 ExWire.Packet.Capability.Eth.NewBlock => 0x17
               }
             }
    end
  end
end
