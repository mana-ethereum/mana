defmodule ExWire.Kademlia.BucketTest do
  use ExUnit.Case, async: true

  doctest ExWire.Kademlia.Bucket

  alias ExWire.Kademlia.{Config, Node, Bucket}

  describe "add_node/3" do
    setup do
      bucket = Bucket.new(time: :test)

      [bucket: bucket]
    end

    test "inserts new node to bucket", %{bucket: bucket} do
      node =
        Node.new(
          <<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79, 124, 126, 164, 120,
            206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48, 148, 233, 203, 201, 33, 110,
            122, 163, 73, 105, 18, 66, 87, 109, 85, 42, 42, 86, 170, 234, 228, 38, 197, 48, 61,
            237, 103, 124, 228, 85, 186, 26, 205, 157>>
        )

      {:insert_node, ^node, bucket} = bucket |> Bucket.refresh_node(node)

      assert Bucket.member?(bucket, node)
    end

    test "reinsert node to bucket", %{bucket: bucket} do
      node =
        Node.new(
          <<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79, 124, 126, 164, 120,
            206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48, 148, 233, 203, 201, 33, 110,
            122, 163, 73, 105, 18, 66, 87, 109, 85, 42, 42, 86, 170, 234, 228, 38, 197, 48, 61,
            237, 103, 124, 228, 85, 186, 26, 205, 157>>
        )

      {:insert_node, ^node, bucket} = bucket |> Bucket.refresh_node(node)

      {:reinsert_node, ^node, bucket} =
        bucket
        |> Bucket.insert_node(node)
        |> Bucket.refresh_node(node)

      assert Bucket.member?(bucket, node)
    end

    test "does not insert node when bucket is full", %{bucket: bucket} do
      node1 =
        Node.new(
          <<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79, 124, 126, 164, 120,
            206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48, 148, 233, 203, 201, 33, 110,
            122, 163, 73, 105, 18, 66, 87, 109, 85, 42, 42, 86, 170, 234, 228, 38, 197, 48, 61,
            237, 103, 124, 228, 85, 186, 26, 205, 157>>
        )

      node2 =
        Node.new(
          <<4, 48, 183, 171, 48, 160, 28, 18, 74, 108, 206, 202, 54, 134, 62, 206, 18, 196, 245,
            250, 104, 227, 186, 155, 11, 81, 64, 124, 204, 0, 46, 238, 211, 179, 16, 45, 32, 168,
            143, 28, 29, 60, 49, 84, 226, 68, 147, 23, 184, 239, 149, 9, 14, 119, 179, 18, 213,
            204, 57, 53, 79, 134, 213, 214, 6>>
        )

      bucket =
        1..Config.bucket_size()
        |> Enum.reduce(bucket, fn _num, acc ->
          acc |> Bucket.insert_node(node1)
        end)

      {:full_bucket, ^node1, ^bucket} = bucket |> Bucket.refresh_node(node2)
    end
  end
end
