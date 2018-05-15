defmodule ExWire.Kademlia.BucketTest do
  use ExUnit.Case, async: true

  doctest ExWire.Kademlia.Bucket

  alias ExWire.Kademlia.{Config, Bucket}
  alias ExWire.TestHelper

  describe "add_node/3" do
    setup do
      bucket = Bucket.new(time: :test)

      [bucket: bucket]
    end

    test "inserts new node to bucket", %{bucket: bucket} do
      node = TestHelper.random_node()

      {:insert_node, ^node, bucket} = bucket |> Bucket.refresh_node(node)

      assert Bucket.member?(bucket, node)
    end

    test "reinsert node to bucket", %{bucket: bucket} do
      node = TestHelper.random_node()

      {:insert_node, ^node, bucket} = bucket |> Bucket.refresh_node(node)

      {:reinsert_node, ^node, bucket} =
        bucket
        |> Bucket.insert_node(node)
        |> Bucket.refresh_node(node)

      assert Bucket.member?(bucket, node)
    end

    test "does not insert node when bucket is full", %{bucket: bucket} do
      node1 = TestHelper.random_node()
      node2 = TestHelper.random_node()

      bucket =
        1..Config.bucket_size()
        |> Enum.reduce(bucket, fn _num, acc ->
          acc |> Bucket.insert_node(node1)
        end)

      {:full_bucket, ^node1, ^bucket} = bucket |> Bucket.refresh_node(node2)
    end
  end
end
