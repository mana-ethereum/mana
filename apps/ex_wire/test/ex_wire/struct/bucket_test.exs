defmodule ExWire.Struct.BucketTest do
  use ExUnit.Case, async: true

  doctest ExWire.Struct.Bucket

  alias ExWire.Struct.Bucket
  alias ExWire.KademliaConfig

  describe "add_node/3" do
    setup do
      bucket = ExWire.Struct.Bucket.new(time: :test)

      [bucket: bucket]
    end

    test "inserts new node to bucket", %{bucket: bucket} do
      node =
        ExWire.Struct.Peer.new(
          "13.84.180.140",
          30303,
          "30b7ab30a01c124a6cceca36863ece12c4f5fa68e3ba9b0b51407ccc002eeed3b3102d20a88f1c1d3c3154e2449317b8ef95090e77b312d5cc39354f86d5d606"
        )

      {:insert_node, ^node, bucket} = bucket |> Bucket.add_node(node)

      assert Bucket.member?(bucket, node)
    end

    test "reinsert node to bucket", %{bucket: bucket} do
      node =
        ExWire.Struct.Peer.new(
          "13.84.180.140",
          30303,
          "30b7ab30a01c124a6cceca36863ece12c4f5fa68e3ba9b0b51407ccc002eeed3b3102d20a88f1c1d3c3154e2449317b8ef95090e77b312d5cc39354f86d5d606"
        )

      {:reinsert_node, ^node, bucket} =
        bucket
        |> Bucket.insert_node(node)
        |> Bucket.add_node(node)

      assert Bucket.member?(bucket, node)
    end

    test "does not insert node when bucket is full", %{bucket: bucket} do
      node1 =
        ExWire.Struct.Peer.new(
          "13.84.180.140",
          30303,
          "30b7ab30a01c124a6cceca36863ece12c4f5fa68e3ba9b0b51407ccc002eeed3b3102d20a88f1c1d3c3154e2449317b8ef95090e77b312d5cc39354f86d5d606"
        )

      node2 =
        ExWire.Struct.Peer.new(
          "13.84.181.140",
          30303,
          "20c9ad97c081d63397d7b685a412227a40e23c8bdc6688c6f37e97cfbc22d2b4d1db1510d8f61e6a8866ad7f0e17c02b14182d37ea7c3c8b9c2683aeb6b733a1"
        )

      bucket =
        1..KademliaConfig.bucket_size()
        |> Enum.reduce(bucket, fn _num, acc ->
          acc |> Bucket.insert_node(node1)
        end)

      {:full_bucket, ^node1, ^bucket} = bucket |> Bucket.add_node(node2)
    end
  end
end
