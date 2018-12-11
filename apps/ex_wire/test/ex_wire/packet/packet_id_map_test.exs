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
          ExWire.Packet.Capability.new({"derp", 1}),
          ExWire.Packet.Capability.new({"eth", 60})
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
      map = ExWire.Packet.PacketIdMap.new([ExWire.Packet.Capability.new({"eth", 62})])

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

    test "Two Different ETH Capabilities" do
      map =
        ExWire.Packet.PacketIdMap.new([
          ExWire.Packet.Capability.new({"eth", 61}),
          ExWire.Packet.Capability.new({"eth", 62})
        ])

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

    test "Eth 62, Par 1" do
      map =
        ExWire.Packet.PacketIdMap.new([
          ExWire.Packet.Capability.new({"eth", 62}),
          ExWire.Packet.Capability.new({"par", 1})
        ])

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
                 0x17 => ExWire.Packet.Capability.Eth.NewBlock,
                 0x21 => ExWire.Packet.Capability.Par.WarpStatus,
                 0x22 => ExWire.Packet.Capability.Par.NewBlockHashes,
                 0x23 => ExWire.Packet.Capability.Par.Transactions,
                 0x24 => ExWire.Packet.Capability.Par.GetBlockHeaders,
                 0x25 => ExWire.Packet.Capability.Par.BlockHeaders,
                 0x26 => ExWire.Packet.Capability.Par.GetBlockBodies,
                 0x27 => ExWire.Packet.Capability.Par.BlockBodies,
                 0x28 => ExWire.Packet.Capability.Par.NewBlock,
                 0x2E => ExWire.Packet.Capability.Par.GetNodeData,
                 0x2F => ExWire.Packet.Capability.Par.NodeData,
                 0x30 => ExWire.Packet.Capability.Par.GetReceipts,
                 0x31 => ExWire.Packet.Capability.Par.Receipts,
                 0x32 => ExWire.Packet.Capability.Par.GetSnapshotManifest,
                 0x33 => ExWire.Packet.Capability.Par.SnapshotManifest,
                 0x34 => ExWire.Packet.Capability.Par.GetSnapshotData,
                 0x35 => ExWire.Packet.Capability.Par.SnapshotData
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
                 ExWire.Packet.Capability.Eth.NewBlock => 0x17,
                 ExWire.Packet.Capability.Par.WarpStatus => 0x21,
                 ExWire.Packet.Capability.Par.NewBlockHashes => 0x22,
                 ExWire.Packet.Capability.Par.Transactions => 0x23,
                 ExWire.Packet.Capability.Par.GetBlockHeaders => 0x24,
                 ExWire.Packet.Capability.Par.BlockHeaders => 0x25,
                 ExWire.Packet.Capability.Par.GetBlockBodies => 0x26,
                 ExWire.Packet.Capability.Par.BlockBodies => 0x27,
                 ExWire.Packet.Capability.Par.NewBlock => 0x28,
                 ExWire.Packet.Capability.Par.GetNodeData => 0x2E,
                 ExWire.Packet.Capability.Par.NodeData => 0x2F,
                 ExWire.Packet.Capability.Par.GetReceipts => 0x30,
                 ExWire.Packet.Capability.Par.Receipts => 0x31,
                 ExWire.Packet.Capability.Par.GetSnapshotManifest => 0x32,
                 ExWire.Packet.Capability.Par.SnapshotManifest => 0x33,
                 ExWire.Packet.Capability.Par.GetSnapshotData => 0x34,
                 ExWire.Packet.Capability.Par.SnapshotData => 0x35
               }
             }
    end

    test "Eth 63, Par 1" do
      map =
        ExWire.Packet.PacketIdMap.new([
          ExWire.Packet.Capability.new({"eth", 63}),
          ExWire.Packet.Capability.new({"par", 1})
        ])

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
                 0x17 => ExWire.Packet.Capability.Eth.NewBlock,
                 0x1D => ExWire.Packet.Capability.Eth.GetNodeData,
                 0x1E => ExWire.Packet.Capability.Eth.NodeData,
                 0x1F => ExWire.Packet.Capability.Eth.GetReceipts,
                 0x20 => ExWire.Packet.Capability.Eth.Receipts,
                 0x21 => ExWire.Packet.Capability.Par.WarpStatus,
                 0x22 => ExWire.Packet.Capability.Par.NewBlockHashes,
                 0x23 => ExWire.Packet.Capability.Par.Transactions,
                 0x24 => ExWire.Packet.Capability.Par.GetBlockHeaders,
                 0x25 => ExWire.Packet.Capability.Par.BlockHeaders,
                 0x26 => ExWire.Packet.Capability.Par.GetBlockBodies,
                 0x27 => ExWire.Packet.Capability.Par.BlockBodies,
                 0x28 => ExWire.Packet.Capability.Par.NewBlock,
                 0x2E => ExWire.Packet.Capability.Par.GetNodeData,
                 0x2F => ExWire.Packet.Capability.Par.NodeData,
                 0x30 => ExWire.Packet.Capability.Par.GetReceipts,
                 0x31 => ExWire.Packet.Capability.Par.Receipts,
                 0x32 => ExWire.Packet.Capability.Par.GetSnapshotManifest,
                 0x33 => ExWire.Packet.Capability.Par.SnapshotManifest,
                 0x34 => ExWire.Packet.Capability.Par.GetSnapshotData,
                 0x35 => ExWire.Packet.Capability.Par.SnapshotData
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
                 ExWire.Packet.Capability.Eth.NewBlock => 0x17,
                 ExWire.Packet.Capability.Eth.GetNodeData => 0x1D,
                 ExWire.Packet.Capability.Eth.NodeData => 0x1E,
                 ExWire.Packet.Capability.Eth.GetReceipts => 0x1F,
                 ExWire.Packet.Capability.Eth.Receipts => 0x20,
                 ExWire.Packet.Capability.Par.WarpStatus => 0x21,
                 ExWire.Packet.Capability.Par.NewBlockHashes => 0x22,
                 ExWire.Packet.Capability.Par.Transactions => 0x23,
                 ExWire.Packet.Capability.Par.GetBlockHeaders => 0x24,
                 ExWire.Packet.Capability.Par.BlockHeaders => 0x25,
                 ExWire.Packet.Capability.Par.GetBlockBodies => 0x26,
                 ExWire.Packet.Capability.Par.BlockBodies => 0x27,
                 ExWire.Packet.Capability.Par.NewBlock => 0x28,
                 ExWire.Packet.Capability.Par.GetNodeData => 0x2E,
                 ExWire.Packet.Capability.Par.NodeData => 0x2F,
                 ExWire.Packet.Capability.Par.GetReceipts => 0x30,
                 ExWire.Packet.Capability.Par.Receipts => 0x31,
                 ExWire.Packet.Capability.Par.GetSnapshotManifest => 0x32,
                 ExWire.Packet.Capability.Par.SnapshotManifest => 0x33,
                 ExWire.Packet.Capability.Par.GetSnapshotData => 0x34,
                 ExWire.Packet.Capability.Par.SnapshotData => 0x35
               }
             }
    end
  end
end
