defmodule ExWire.Struct.Bucket do
  @moduledoc """
  Represents a Kademlia k-bucket.
  """

  alias ExWire.Struct.{Peer, Bucket}
  alias ExWire.Util.Timestamp
  alias ExWire.KademliaConfig

  defstruct [:current_node, :nodes, :updated_at]

  @type t :: %__MODULE__{
          current_node: Peer.t(),
          nodes: [Peer.t()],
          updated_at: integer()
        }

  @doc """
  Creates new bucket.

  ## Examples

      iex> node = ExWire.Struct.Peer.new("13.84.180.240", 30303, "6ce05930c72abc632c58e2e4324f7c7ea478cec0ed4fa2528982cf34483094e9cbc9216e7aa349691242576d552a2a56aaeae426c5303ded677ce455ba1acd9d", time: :test)
      iex> node |> ExWire.Struct.Bucket.new(time: :test)
      %ExWire.Struct.Bucket{
        current_node: %ExWire.Struct.Peer{
          host: "13.84.180.240",
          ident: "6ce059...1acd9d",
          last_seen: 1525704921,
          port: 30303,
          remote_id: <<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50,
            79, 124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72,
            48, 148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85,
            42, 42, 86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186,
            26, 205, 157>>
        },
        nodes: [],
        updated_at: 1525704921
      }

  """
  @spec new(Peer.t()) :: t()
  def new(node = %Peer{}, options \\ [time: :actual]) do
    %__MODULE__{
      current_node: node,
      nodes: [],
      updated_at: Timestamp.now(options[:time])
    }
  end

  @doc """
  Adds a node to bucket. Returns tuple with insert result, inserted node and updated bucket.

  ## Examples

      iex> node1 = ExWire.Struct.Peer.new("13.84.180.240", 30303, "6ce05930c72abc632c58e2e4324f7c7ea478cec0ed4fa2528982cf34483094e9cbc9216e7aa349691242576d552a2a56aaeae426c5303ded677ce455ba1acd9d", time: :test)
      iex> node2 = ExWire.Struct.Peer.new("13.84.180.140", 30303, "30b7ab30a01c124a6cceca36863ece12c4f5fa68e3ba9b0b51407ccc002eeed3b3102d20a88f1c1d3c3154e2449317b8ef95090e77b312d5cc39354f86d5d606", time: :test)
      iex> node1
      ...>   |> ExWire.Struct.Bucket.new(time: :test)
      ...>   |> ExWire.Struct.Bucket.add_node(node2, time: :test)
      {:insert_node,
       %ExWire.Struct.Peer{
         host: "13.84.180.140",
         ident: "30b7ab...d5d606",
         last_seen: 1525704921,
         port: 30303,
         remote_id: <<4, 48, 183, 171, 48, 160, 28, 18, 74, 108, 206, 202, 54, 134,
           62, 206, 18, 196, 245, 250, 104, 227, 186, 155, 11, 81, 64, 124, 204, 0,
           46, 238, 211, 179, 16, 45, 32, 168, 143, 28, 29, 60, 49, 84, 226, 68, 147,
           23, 184, 239, 149, 9, 14, 119, 179, 18, 213, 204, 57, 53, 79, 134, 213,
           214, 6>>
       },
       %ExWire.Struct.Bucket{
         current_node: %ExWire.Struct.Peer{
           host: "13.84.180.240",
           ident: "6ce059...1acd9d",
           last_seen: 1525704921,
           port: 30303,
           remote_id: <<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50,
             79, 124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52,
             72, 48, 148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109,
             85, 42, 42, 86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85,
             186, 26, 205, 157>>
         },
         nodes: [
           %ExWire.Struct.Peer{
             host: "13.84.180.140",
             ident: "30b7ab...d5d606",
             last_seen: 1525704921,
             port: 30303,
             remote_id: <<4, 48, 183, 171, 48, 160, 28, 18, 74, 108, 206, 202, 54,
               134, 62, 206, 18, 196, 245, 250, 104, 227, 186, 155, 11, 81, 64, 124,
               204, 0, 46, 238, 211, 179, 16, 45, 32, 168, 143, 28, 29, 60, 49, 84,
               226, 68, 147, 23, 184, 239, 149, 9, 14, 119, 179, 18, 213, 204, 57, 53,
               79, 134, 213, 214, 6>>
           }
         ],
         updated_at: 1525704921
       }}
  """
  @spec add_node(t(), Peer.t()) :: {atom, t()}
  def add_node(bucket = %Bucket{current_node: current_node}, node, options \\ [time: :actual]) do
    cond do
      Peer.equal?(current_node, node) -> {:current_node, nil, bucket}
      member?(bucket, node) -> {:reinsert_node, node, reinsert_node(bucket, node, options)}
      full?(bucket) -> {:full_bucket, tail(bucket), bucket}
      true -> {:insert_node, node, insert_node(bucket, node, options)}
    end
  end

  @doc """
  Returns bucket's first node.

  ## Examples

      iex> node1 = ExWire.Struct.Peer.new("13.84.180.240", 30303, "6ce05930c72abc632c58e2e4324f7c7ea478cec0ed4fa2528982cf34483094e9cbc9216e7aa349691242576d552a2a56aaeae426c5303ded677ce455ba1acd9d", time: :test)
      iex> node2 = ExWire.Struct.Peer.new("13.84.180.140", 30303, "30b7ab30a01c124a6cceca36863ece12c4f5fa68e3ba9b0b51407ccc002eeed3b3102d20a88f1c1d3c3154e2449317b8ef95090e77b312d5cc39354f86d5d606", time: :test)
      iex> node1
      ...>   |> ExWire.Struct.Bucket.new(time: :test)
      ...>   |> ExWire.Struct.Bucket.insert_node(node2, time: :test)
      ...>   |> ExWire.Struct.Bucket.head()
      %ExWire.Struct.Peer{
        host: "13.84.180.140",
        ident: "30b7ab...d5d606",
        last_seen: 1525704921,
        port: 30303,
        remote_id: <<4, 48, 183, 171, 48, 160, 28, 18, 74, 108, 206, 202, 54, 134,
          62, 206, 18, 196, 245, 250, 104, 227, 186, 155, 11, 81, 64, 124, 204, 0,
          46, 238, 211, 179, 16, 45, 32, 168, 143, 28, 29, 60, 49, 84, 226, 68,
          147, 23, 184, 239, 149, 9, 14, 119, 179, 18, 213, 204, 57, 53, 79, 134,
          213, 214, 6>>
      }
  """
  @spec head(t()) :: Peer.t()
  def head(%Bucket{nodes: [node | _nodes_tail]}), do: node

  @doc """
  Returns bucket's last node.

  ## Examples

      iex> node1 = ExWire.Struct.Peer.new("13.84.180.240", 30303, "6ce05930c72abc632c58e2e4324f7c7ea478cec0ed4fa2528982cf34483094e9cbc9216e7aa349691242576d552a2a56aaeae426c5303ded677ce455ba1acd9d", time: :test)
      iex> node2 = ExWire.Struct.Peer.new("13.84.180.140", 30303, "30b7ab30a01c124a6cceca36863ece12c4f5fa68e3ba9b0b51407ccc002eeed3b3102d20a88f1c1d3c3154e2449317b8ef95090e77b312d5cc39354f86d5d606", time: :test)
      iex> node3 = ExWire.Struct.Peer.new("13.84.181.140", 30303, "20c9ad97c081d63397d7b685a412227a40e23c8bdc6688c6f37e97cfbc22d2b4d1db1510d8f61e6a8866ad7f0e17c02b14182d37ea7c3c8b9c2683aeb6b733a1", time: :test)
      iex> node1
      ...>   |> ExWire.Struct.Bucket.new(time: :test)
      ...>   |> ExWire.Struct.Bucket.insert_node(node2, time: :test)
      ...>   |> ExWire.Struct.Bucket.insert_node(node3, time: :test)
      ...>   |> ExWire.Struct.Bucket.tail()
      %ExWire.Struct.Peer{
        host: "13.84.180.140",
        ident: "30b7ab...d5d606",
        last_seen: 1525704921,
        port: 30303,
        remote_id: <<4, 48, 183, 171, 48, 160, 28, 18, 74, 108, 206, 202, 54, 134,
          62, 206, 18, 196, 245, 250, 104, 227, 186, 155, 11, 81, 64, 124, 204, 0,
          46, 238, 211, 179, 16, 45, 32, 168, 143, 28, 29, 60, 49, 84, 226, 68,
          147, 23, 184, 239, 149, 9, 14, 119, 179, 18, 213, 204, 57, 53, 79, 134,
          213, 214, 6>>
      }
  """
  @spec tail(t()) :: Peer.t()
  def tail(%Bucket{nodes: nodes}), do: nodes |> List.last()

  @doc """
  Remove node from bucket.

  ## Examples

      iex> node1 = ExWire.Struct.Peer.new("13.84.180.240", 30303, "6ce05930c72abc632c58e2e4324f7c7ea478cec0ed4fa2528982cf34483094e9cbc9216e7aa349691242576d552a2a56aaeae426c5303ded677ce455ba1acd9d", time: :test)
      iex> node2 = ExWire.Struct.Peer.new("13.84.180.140", 30303, "30b7ab30a01c124a6cceca36863ece12c4f5fa68e3ba9b0b51407ccc002eeed3b3102d20a88f1c1d3c3154e2449317b8ef95090e77b312d5cc39354f86d5d606", time: :test)
      iex> node1
      ...>   |> ExWire.Struct.Bucket.new(time: :test)
      ...>   |> ExWire.Struct.Bucket.insert_node(node2, time: :test)
      %ExWire.Struct.Bucket{
        current_node: %ExWire.Struct.Peer{
          host: "13.84.180.240",
          ident: "6ce059...1acd9d",
          last_seen: 1525704921,
          port: 30303,
          remote_id: <<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50,
            79, 124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72,
            48, 148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85,
            42, 42, 86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186,
            26, 205, 157>>
        },
        nodes: [
          %ExWire.Struct.Peer{
            host: "13.84.180.140",
            ident: "30b7ab...d5d606",
            last_seen: 1525704921,
            port: 30303,
            remote_id: <<4, 48, 183, 171, 48, 160, 28, 18, 74, 108, 206, 202, 54, 134,
              62, 206, 18, 196, 245, 250, 104, 227, 186, 155, 11, 81, 64, 124, 204, 0,
              46, 238, 211, 179, 16, 45, 32, 168, 143, 28, 29, 60, 49, 84, 226, 68,
              147, 23, 184, 239, 149, 9, 14, 119, 179, 18, 213, 204, 57, 53, 79, 134,
              213, 214, 6>>
          }
        ],
        updated_at: 1525704921
      }
  """
  @spec insert_node(t(), Peer.t(), Keyword.t()) :: t()
  def insert_node(bucket = %Bucket{nodes: nodes}, node, options \\ [time: :actual]) do
    %{bucket | nodes: [node | nodes], updated_at: Timestamp.now(options[:time])}
  end

  @doc """
  Remove node from bucket.

  ## Examples

      iex> node1 = ExWire.Struct.Peer.new("13.84.180.240", 30303, "6ce05930c72abc632c58e2e4324f7c7ea478cec0ed4fa2528982cf34483094e9cbc9216e7aa349691242576d552a2a56aaeae426c5303ded677ce455ba1acd9d", time: :test)
      iex> node2 = ExWire.Struct.Peer.new("13.84.180.140", 30303, "30b7ab30a01c124a6cceca36863ece12c4f5fa68e3ba9b0b51407ccc002eeed3b3102d20a88f1c1d3c3154e2449317b8ef95090e77b312d5cc39354f86d5d606", time: :test)
      iex> bucket =
      ...>   node1
      ...>   |> ExWire.Struct.Bucket.new(time: :test)
      ...>   |> ExWire.Struct.Bucket.insert_node(node2, time: :test)
      %ExWire.Struct.Bucket{
        current_node: %ExWire.Struct.Peer{
          host: "13.84.180.240",
          ident: "6ce059...1acd9d",
          last_seen: 1525704921,
          port: 30303,
          remote_id: <<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50,
            79, 124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72,
            48, 148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85,
            42, 42, 86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186,
            26, 205, 157>>
        },
        nodes: [
          %ExWire.Struct.Peer{
            host: "13.84.180.140",
            ident: "30b7ab...d5d606",
            last_seen: 1525704921,
            port: 30303,
            remote_id: <<4, 48, 183, 171, 48, 160, 28, 18, 74, 108, 206, 202, 54, 134,
              62, 206, 18, 196, 245, 250, 104, 227, 186, 155, 11, 81, 64, 124, 204, 0,
              46, 238, 211, 179, 16, 45, 32, 168, 143, 28, 29, 60, 49, 84, 226, 68,
              147, 23, 184, 239, 149, 9, 14, 119, 179, 18, 213, 204, 57, 53, 79, 134,
              213, 214, 6>>
          }
        ],
        updated_at: 1525704921
      }
      iex> bucket |> ExWire.Struct.Bucket.remove_node(node2)
      %ExWire.Struct.Bucket{
         current_node: %ExWire.Struct.Peer{
           host: "13.84.180.240",
           ident: "6ce059...1acd9d",
           last_seen: 1525704921,
           port: 30303,
           remote_id: <<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50,
             79, 124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72,
             48, 148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85,
             42, 42, 86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186,
             26, 205, 157>>
         },
         nodes: [],
         updated_at: 1525704921
       }
  """
  @spec remove_node(t(), Peer.t()) :: t()
  def remove_node(bucket = %Bucket{nodes: nodes}, node) do
    new_nodes =
      nodes
      |> Enum.drop_while(fn bucket_node ->
        Peer.equal?(node, bucket_node)
      end)

    %{bucket | nodes: new_nodes}
  end

  @doc """
  Reinsert node to the beginnig of bucket.

  ## Examples

      iex> node1 = ExWire.Struct.Peer.new("13.84.180.240", 30303, "6ce05930c72abc632c58e2e4324f7c7ea478cec0ed4fa2528982cf34483094e9cbc9216e7aa349691242576d552a2a56aaeae426c5303ded677ce455ba1acd9d", time: :test)
      iex> node2 = ExWire.Struct.Peer.new("13.84.180.140", 30303, "30b7ab30a01c124a6cceca36863ece12c4f5fa68e3ba9b0b51407ccc002eeed3b3102d20a88f1c1d3c3154e2449317b8ef95090e77b312d5cc39354f86d5d606", time: :test)
      iex> node3 = ExWire.Struct.Peer.new("13.84.181.140", 30303, "20c9ad97c081d63397d7b685a412227a40e23c8bdc6688c6f37e97cfbc22d2b4d1db1510d8f61e6a8866ad7f0e17c02b14182d37ea7c3c8b9c2683aeb6b733a1", time: :test)
      iex> bucket =
      ...>   node1
      ...>   |> ExWire.Struct.Bucket.new()
      ...>   |> ExWire.Struct.Bucket.insert_node(node2)
      ...>   |> ExWire.Struct.Bucket.insert_node(node3)
      iex> head1 = bucket |> ExWire.Struct.Bucket.head()
      iex> head1 == node3
      true
      iex> head2 = bucket |> ExWire.Struct.Bucket.reinsert_node(node2) |> ExWire.Struct.Bucket.head()
      iex> head2 == node2
      true
  """
  def reinsert_node(bucket = %Bucket{}, node, options \\ []) do
    bucket
    |> remove_node(node)
    |> insert_node(node, options)
  end

  @doc """
  Checks if node exists in bucket.

  ## Examples

      iex> node1 = ExWire.Struct.Peer.new("13.84.180.240", 30303, "6ce05930c72abc632c58e2e4324f7c7ea478cec0ed4fa2528982cf34483094e9cbc9216e7aa349691242576d552a2a56aaeae426c5303ded677ce455ba1acd9d")
      iex> node2 = ExWire.Struct.Peer.new("13.84.180.140", 30303, "30b7ab30a01c124a6cceca36863ece12c4f5fa68e3ba9b0b51407ccc002eeed3b3102d20a88f1c1d3c3154e2449317b8ef95090e77b312d5cc39354f86d5d606")
      iex> bucket = ExWire.Struct.Bucket.new(node1)
      iex> bucket |> ExWire.Struct.Bucket.member?(node2)
      false
      iex> bucket |> ExWire.Struct.Bucket.insert_node(node2) |> ExWire.Struct.Bucket.member?(node2)
      true
  """
  @spec member?(t(), Peer.t()) :: boolean()
  def member?(%Bucket{nodes: nodes}, node) do
    nodes
    |> Enum.any?(fn bucket_node ->
      Peer.equal?(bucket_node, node)
    end)
  end

  @doc """
  Checks if bucket is full. See `ExWire.KademliaConfig` for `bucket_size` parameter

  ## Examples

      iex> node = ExWire.Struct.Peer.new("13.84.180.240", 30303, "6ce05930c72abc632c58e2e4324f7c7ea478cec0ed4fa2528982cf34483094e9cbc9216e7aa349691242576d552a2a56aaeae426c5303ded677ce455ba1acd9d")
      iex> bucket = ExWire.Struct.Bucket.new(node)
      iex> bucket |> ExWire.Struct.Bucket.full?()
      false
  """

  @spec full?(t()) :: boolean()
  def full?(%Bucket{nodes: nodes}) do
    Enum.count(nodes) == KademliaConfig.bucket_size()
  end
end
