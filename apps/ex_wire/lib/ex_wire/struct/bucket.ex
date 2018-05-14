defmodule ExWire.Struct.Bucket do
  @moduledoc """
  Represents a Kademlia k-bucket.
  """

  alias ExWire.Struct.{Node, Bucket}
  alias ExWire.Util.Timestamp
  alias ExWire.KademliaConfig

  defstruct [:id, :nodes, :updated_at]

  @type t :: %__MODULE__{
          id: integer(),
          nodes: [Node.t()],
          updated_at: integer()
        }

  @doc """
  Creates new bucket.

  ## Examples
      iex> ExWire.Struct.Bucket.new(1, time: :test)
      %ExWire.Struct.Bucket{
        id: 1,
        nodes: [],
        updated_at: 1525704921
      }

  """
  @spec new(integer()) :: t()
  def new(id, options \\ [time: :actual]) do
    %__MODULE__{
      id: id,
      nodes: [],
      updated_at: Timestamp.now(options[:time])
    }
  end

  @doc """
  Returns nodes of a given bucket.
  """
  @spec nodes(t()) :: [Node.t()]
  def nodes(%__MODULE__{nodes: nodes}), do: nodes

  @doc """
  Adds a node to bucket. Returns tuple with insert result, inserted node and updated bucket.

  ## Examples

      iex> node = ExWire.Struct.Node.new(<<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79,
      ...>      124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48,
      ...>      148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85, 42, 42,
      ...>      86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186, 26, 205,
      ...>      157>>)
      iex> ExWire.Struct.Bucket.new(1, time: :test)
      ...> |> ExWire.Struct.Bucket.refresh_node(node, time: :test)
      {:insert_node,
      %ExWire.Struct.Node{
        key: <<115, 3, 97, 5, 230, 214, 202, 188, 202, 118, 204, 177, 15, 72, 13, 68,
          134, 100, 145, 57, 13, 239, 13, 175, 42, 38, 147, 127, 31, 18, 27, 226>>,
        public_key: <<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79,
          124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48,
          148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85, 42, 42,
          86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186, 26, 205,
          157>>
      },
       %ExWire.Struct.Bucket{
         id: 1,
         nodes: [
           %ExWire.Struct.Node{
             key: <<115, 3, 97, 5, 230, 214, 202, 188, 202, 118, 204, 177, 15, 72, 13, 68,
               134, 100, 145, 57, 13, 239, 13, 175, 42, 38, 147, 127, 31, 18, 27, 226>>,
             public_key: <<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79,
               124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48,
               148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85, 42, 42,
               86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186, 26, 205,
               157>>
           }
         ],
         updated_at: 1525704921
       }}
  """
  @spec refresh_node(t(), Node.t(), Keyword.t()) :: {atom, t()}
  def refresh_node(bucket = %Bucket{}, node, options \\ [time: :actual]) do
    cond do
      member?(bucket, node) -> {:reinsert_node, node, reinsert_node(bucket, node, options)}
      full?(bucket) -> {:full_bucket, last(bucket), bucket}
      true -> {:insert_node, node, insert_node(bucket, node, options)}
    end
  end

  @doc """
  Returns bucket's first node.

  ## Examples

      iex> node = ExWire.Struct.Node.new(<<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79,
      ...>      124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48,
      ...>      148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85, 42, 42,
      ...>      86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186, 26, 205,
      ...>      157>>)
      iex> ExWire.Struct.Bucket.new(1, time: :test)
      ...>   |> ExWire.Struct.Bucket.insert_node(node, time: :test)
      ...>   |> ExWire.Struct.Bucket.head()
      %ExWire.Struct.Node{
        key: <<115, 3, 97, 5, 230, 214, 202, 188, 202, 118, 204, 177, 15, 72, 13, 68,
          134, 100, 145, 57, 13, 239, 13, 175, 42, 38, 147, 127, 31, 18, 27, 226>>,
        public_key: <<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79,
          124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48,
          148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85, 42, 42,
          86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186, 26, 205,
          157>>
      }
  """
  @spec head(t()) :: Peer.t()
  def head(%Bucket{nodes: [node | _nodes_tail]}), do: node

  @doc """
  Returns bucket's last node.

  ## Examples

      iex> node = ExWire.Struct.Peer.new("13.84.180.140", 30303, "30b7ab30a01c124a6cceca36863ece12c4f5fa68e3ba9b0b51407ccc002eeed3b3102d20a88f1c1d3c3154e2449317b8ef95090e77b312d5cc39354f86d5d606", time: :test)
      iex> node1 = ExWire.Struct.Peer.new("13.84.181.140", 30303, "20c9ad97c081d63397d7b685a412227a40e23c8bdc6688c6f37e97cfbc22d2b4d1db1510d8f61e6a8866ad7f0e17c02b14182d37ea7c3c8b9c2683aeb6b733a1", time: :test)
      iex> ExWire.Struct.Bucket.new(1, time: :test)
      ...>   |> ExWire.Struct.Bucket.insert_node(node, time: :test)
      ...>   |> ExWire.Struct.Bucket.insert_node(node1, time: :test)
      ...>   |> ExWire.Struct.Bucket.last()
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
  @spec last(t()) :: Peer.t()
  def last(%Bucket{nodes: nodes}), do: nodes |> List.last()

  @doc """
  Inserts node to bucket.

  ## Examples

      iex> node = ExWire.Struct.Peer.new("13.84.180.140", 30303, "30b7ab30a01c124a6cceca36863ece12c4f5fa68e3ba9b0b51407ccc002eeed3b3102d20a88f1c1d3c3154e2449317b8ef95090e77b312d5cc39354f86d5d606", time: :test)
      iex> ExWire.Struct.Bucket.new(1, time: :test)
      ...> |> ExWire.Struct.Bucket.insert_node(node, time: :test)
      %ExWire.Struct.Bucket{
        id: 1,
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

      iex> node = ExWire.Struct.Peer.new("13.84.180.140", 30303, "30b7ab30a01c124a6cceca36863ece12c4f5fa68e3ba9b0b51407ccc002eeed3b3102d20a88f1c1d3c3154e2449317b8ef95090e77b312d5cc39354f86d5d606", time: :test)
      iex> bucket = ExWire.Struct.Bucket.new(1, time: :test)
      ...>   |> ExWire.Struct.Bucket.insert_node(node, time: :test)
      %ExWire.Struct.Bucket{
        id: 1,
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
      iex> bucket |> ExWire.Struct.Bucket.remove_node(node)
      %ExWire.Struct.Bucket{
         id: 1,
         nodes: [],
         updated_at: 1525704921
       }
  """
  @spec remove_node(t(), Peer.t()) :: t()
  def remove_node(bucket = %Bucket{nodes: nodes}, node) do
    new_nodes =
      nodes
      |> Enum.drop_while(fn bucket_node ->
        node == bucket_node
      end)

    %{bucket | nodes: new_nodes}
  end

  @doc """
  Reinsert node to the beginnig of bucket.

  ## Examples

      iex> node1 = ExWire.Struct.Node.new(<<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79,
      ...>       124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48,
      ...>       148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85, 42, 42,
      ...>       86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186, 26, 205,
      ...>       157>>)
      iex> node2 = ExWire.Struct.Node.new(<<4, 48, 183, 171, 48, 160, 28, 18, 74, 108, 206, 202, 54, 134,
      ...>       62, 206, 18, 196, 245, 250, 104, 227, 186, 155, 11, 81, 64, 124, 204, 0,
      ...>       46, 238, 211, 179, 16, 45, 32, 168, 143, 28, 29, 60, 49, 84, 226, 68, 147,
      ...>       23, 184, 239, 149, 9, 14, 119, 179, 18, 213, 204, 57, 53, 79, 134, 213,
      ...>       214, 6>>)
      iex> bucket = ExWire.Struct.Bucket.new(1)
      ...>   |> ExWire.Struct.Bucket.insert_node(node1)
      ...>   |> ExWire.Struct.Bucket.insert_node(node2)
      iex> head1 = bucket |> ExWire.Struct.Bucket.head()
      iex> head1 == node2
      true
      iex> head2 = bucket |> ExWire.Struct.Bucket.reinsert_node(node1) |> ExWire.Struct.Bucket.head()
      iex> head2 == node1
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

      iex> node = ExWire.Struct.Node.new(<<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79,
      ...>      124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48,
      ...>      148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85, 42, 42,
      ...>      86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186, 26, 205,
      ...>      157>>)
      iex> bucket = ExWire.Struct.Bucket.new(1)
      iex> bucket |> ExWire.Struct.Bucket.member?(node)
      false
      iex> bucket |> ExWire.Struct.Bucket.insert_node(node) |> ExWire.Struct.Bucket.member?(node)
      true
  """
  @spec member?(t(), Peer.t()) :: boolean()
  def member?(%Bucket{nodes: nodes}, node) do
    nodes
    |> Enum.any?(fn bucket_node ->
      bucket_node == node
    end)
  end

  @doc """
  Checks if bucket is full. See `ExWire.KademliaConfig` for `bucket_size` parameter

  ## Examples

      iex> bucket = ExWire.Struct.Bucket.new(1)
      iex> bucket |> ExWire.Struct.Bucket.full?()
      false
  """

  @spec full?(t()) :: boolean()
  def full?(%Bucket{nodes: nodes}) do
    Enum.count(nodes) == KademliaConfig.bucket_size()
  end
end
