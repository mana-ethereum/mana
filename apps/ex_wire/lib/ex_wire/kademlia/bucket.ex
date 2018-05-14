defmodule ExWire.Kademlia.Bucket do
  @moduledoc """
  Represents a Kademlia k-bucket.
  """

  alias ExWire.Kademlia.{Node, Config}
  alias ExWire.Util.Timestamp

  defstruct [:id, :nodes, :updated_at]

  @type t :: %__MODULE__{
          id: integer(),
          nodes: [Node.t()],
          updated_at: integer()
        }

  @doc """
  Creates new bucket.

  ## Examples
      iex> ExWire.Kademlia.Bucket.new(1, time: :test)
      %ExWire.Kademlia.Bucket{
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

      iex> node = ExWire.Kademlia.Node.new(<<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79,
      ...>      124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48,
      ...>      148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85, 42, 42,
      ...>      86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186, 26, 205,
      ...>      157>>)
      iex> ExWire.Kademlia.Bucket.new(1, time: :test)
      ...> |> ExWire.Kademlia.Bucket.refresh_node(node, time: :test)
      {:insert_node,
      %ExWire.Kademlia.Node{
        key: <<115, 3, 97, 5, 230, 214, 202, 188, 202, 118, 204, 177, 15, 72, 13, 68,
          134, 100, 145, 57, 13, 239, 13, 175, 42, 38, 147, 127, 31, 18, 27, 226>>,
        public_key: <<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79,
          124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48,
          148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85, 42, 42,
          86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186, 26, 205,
          157>>
      },
       %ExWire.Kademlia.Bucket{
         id: 1,
         nodes: [
           %ExWire.Kademlia.Node{
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
  def refresh_node(bucket = %__MODULE__{}, node, options \\ [time: :actual]) do
    cond do
      member?(bucket, node) -> {:reinsert_node, node, reinsert_node(bucket, node, options)}
      full?(bucket) -> {:full_bucket, last(bucket), bucket}
      true -> {:insert_node, node, insert_node(bucket, node, options)}
    end
  end

  @doc """
  Returns bucket's first node.

  ## Examples

      iex> node = ExWire.Kademlia.Node.new(<<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79,
      ...>      124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48,
      ...>      148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85, 42, 42,
      ...>      86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186, 26, 205,
      ...>      157>>)
      iex> ExWire.Kademlia.Bucket.new(1, time: :test)
      ...>   |> ExWire.Kademlia.Bucket.insert_node(node, time: :test)
      ...>   |> ExWire.Kademlia.Bucket.head()
      %ExWire.Kademlia.Node{
        key: <<115, 3, 97, 5, 230, 214, 202, 188, 202, 118, 204, 177, 15, 72, 13, 68,
          134, 100, 145, 57, 13, 239, 13, 175, 42, 38, 147, 127, 31, 18, 27, 226>>,
        public_key: <<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79,
          124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48,
          148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85, 42, 42,
          86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186, 26, 205,
          157>>
      }
  """
  @spec head(t()) :: Node.t()
  def head(%__MODULE__{nodes: [node | _nodes_tail]}), do: node

  @doc """
  Returns bucket's last node.

  ## Examples

      iex> node = ExWire.Kademlia.Node.new(<<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79,
      ...>      124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48,
      ...>      148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85, 42, 42,
      ...>      86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186, 26, 205,
      ...>      157>>)
      iex> node1 = ExWire.Kademlia.Node.new(<<4, 48, 183, 171, 48, 160, 28, 18, 74, 108, 206, 202, 54, 134,
      ...>       62, 206, 18, 196, 245, 250, 104, 227, 186, 155, 11, 81, 64, 124, 204, 0,
      ...>       46, 238, 211, 179, 16, 45, 32, 168, 143, 28, 29, 60, 49, 84, 226, 68, 147,
      ...>       23, 184, 239, 149, 9, 14, 119, 179, 18, 213, 204, 57, 53, 79, 134, 213,
      ...>       214, 6>>)
      iex> ExWire.Kademlia.Bucket.new(1, time: :test)
      ...>   |> ExWire.Kademlia.Bucket.insert_node(node, time: :test)
      ...>   |> ExWire.Kademlia.Bucket.insert_node(node1, time: :test)
      ...>   |> ExWire.Kademlia.Bucket.last()
      %ExWire.Kademlia.Node{
        key: <<115, 3, 97, 5, 230, 214, 202, 188, 202, 118, 204, 177, 15, 72, 13, 68,
          134, 100, 145, 57, 13, 239, 13, 175, 42, 38, 147, 127, 31, 18, 27, 226>>,
        public_key: <<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79,
          124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48,
          148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85, 42, 42,
          86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186, 26, 205,
          157>>
      }
  """
  @spec last(t()) :: Node.t()
  def last(%__MODULE__{nodes: nodes}), do: nodes |> List.last()

  @doc """
  Inserts node to bucket.

  ## Examples

      iex> node = ExWire.Kademlia.Node.new(<<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79,
      ...>      124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48,
      ...>      148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85, 42, 42,
      ...>      86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186, 26, 205,
      ...>      157>>)
      iex> ExWire.Kademlia.Bucket.new(1, time: :test)
      ...> |> ExWire.Kademlia.Bucket.insert_node(node, time: :test)
      %ExWire.Kademlia.Bucket{
        id: 1,
        nodes: [
          %ExWire.Kademlia.Node{
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
      }
  """
  @spec insert_node(t(), Node.t(), Keyword.t()) :: t()
  def insert_node(bucket = %__MODULE__{nodes: nodes}, node, options \\ [time: :actual]) do
    %{bucket | nodes: [node | nodes], updated_at: Timestamp.now(options[:time])}
  end

  @doc """
  Removes node from bucket.

  ## Examples

      iex> node = ExWire.Kademlia.Node.new(<<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79,
      ...>      124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48,
      ...>      148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85, 42, 42,
      ...>      86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186, 26, 205,
      ...>      157>>)
      iex> bucket = ExWire.Kademlia.Bucket.new(1, time: :test)
      ...>   |> ExWire.Kademlia.Bucket.insert_node(node, time: :test)
      %ExWire.Kademlia.Bucket{
        id: 1,
        nodes: [
          %ExWire.Kademlia.Node{
            key: <<115, 3, 97, 5, 230, 214, 202, 188, 202, 118, 204, 177, 15, 72, 13, 68,
              134, 100, 145, 57, 13, 239, 13, 175, 42, 38, 147, 127, 31, 18, 27, 226>>,
            public_key: <<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79,
              124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48,
              148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85, 42, 42,
              86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186, 26, 205,
              157>>
          },
        ],
        updated_at: 1525704921
      }
      iex> bucket |> ExWire.Kademlia.Bucket.remove_node(node)
      %ExWire.Kademlia.Bucket{
         id: 1,
         nodes: [],
         updated_at: 1525704921
       }
  """
  @spec remove_node(t(), Node.t()) :: t()
  def remove_node(bucket = %__MODULE__{nodes: nodes}, node) do
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

      iex> node1 = ExWire.Kademlia.Node.new(<<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79,
      ...>       124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48,
      ...>       148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85, 42, 42,
      ...>       86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186, 26, 205,
      ...>       157>>)
      iex> node2 = ExWire.Kademlia.Node.new(<<4, 48, 183, 171, 48, 160, 28, 18, 74, 108, 206, 202, 54, 134,
      ...>       62, 206, 18, 196, 245, 250, 104, 227, 186, 155, 11, 81, 64, 124, 204, 0,
      ...>       46, 238, 211, 179, 16, 45, 32, 168, 143, 28, 29, 60, 49, 84, 226, 68, 147,
      ...>       23, 184, 239, 149, 9, 14, 119, 179, 18, 213, 204, 57, 53, 79, 134, 213,
      ...>       214, 6>>)
      iex> bucket = ExWire.Kademlia.Bucket.new(1)
      ...>   |> ExWire.Kademlia.Bucket.insert_node(node1)
      ...>   |> ExWire.Kademlia.Bucket.insert_node(node2)
      iex> head1 = bucket |> ExWire.Kademlia.Bucket.head()
      iex> head1 == node2
      true
      iex> head2 = bucket |> ExWire.Kademlia.Bucket.reinsert_node(node1) |> ExWire.Kademlia.Bucket.head()
      iex> head2 == node1
      true
  """
  def reinsert_node(bucket = %__MODULE__{}, node, options \\ []) do
    bucket
    |> remove_node(node)
    |> insert_node(node, options)
  end

  @doc """
  Checks if node exists in bucket.

  ## Examples

      iex> node = ExWire.Kademlia.Node.new(<<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79,
      ...>      124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48,
      ...>      148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85, 42, 42,
      ...>      86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186, 26, 205,
      ...>      157>>)
      iex> bucket = ExWire.Kademlia.Bucket.new(1)
      iex> bucket |> ExWire.Kademlia.Bucket.member?(node)
      false
      iex> bucket |> ExWire.Kademlia.Bucket.insert_node(node) |> ExWire.Kademlia.Bucket.member?(node)
      true
  """
  @spec member?(t(), Peer.t()) :: boolean()
  def member?(%__MODULE__{nodes: nodes}, node) do
    nodes
    |> Enum.any?(fn bucket_node ->
      bucket_node == node
    end)
  end

  @doc """
  Checks if bucket is full. See `ExWire.Kademlia.Config` for `bucket_size` parameter

  ## Examples

      iex> bucket = ExWire.Kademlia.Bucket.new(1)
      iex> bucket |> ExWire.Kademlia.Bucket.full?()
      false
  """

  @spec full?(t()) :: boolean()
  def full?(%__MODULE__{nodes: nodes}) do
    Enum.count(nodes) == Config.bucket_size()
  end
end
