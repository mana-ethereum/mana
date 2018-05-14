defmodule ExWire.Kademlia.RoutingTable do
  @moduledoc """
  Module for working with current node's buckets
  """

  alias ExWire.Kademlia.{Bucket, Node}
  alias ExWire.Kademlia.Config, as: KademliaConfig

  @network Application.fetch_env(:ex_wire, :network_process_name)

  defstruct [:current_node, :buckets]

  @type t :: %__MODULE__{
          current_node: Node.t(),
          buckets: [Bucket.t()]
        }

  @doc """
  Creates new routing table.

  ## Examples

      iex> node = %ExWire.Kademlia.Node{
      ...>  key: <<115, 3, 97, 5, 230, 214, 202, 188, 202, 118, 204, 177, 15, 72, 13, 68,
      ...>    134, 100, 145, 57, 13, 239, 13, 175, 42, 38, 147, 127, 31, 18, 27, 226>>,
      ...>  public_key: <<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79,
      ...>    124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48,
      ...>    148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85, 42, 42,
      ...>    86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186, 26, 205,
      ...>    157>>
      ...> }
      iex> table = node |> ExWire.Kademlia.RoutingTable.new()
      iex> table.buckets |> Enum.count
      256
  """
  @spec new(Node.t()) :: t()
  def new(node = %Node{}) do
    initial_buckets = initialize_buckets()

    %__MODULE__{
      current_node: node,
      buckets: initial_buckets
    }
  end

  @doc """
  Returns table's buckets.
  """
  @spec buckets(t()) :: [Bucket.t()]
  def buckets(%__MODULE__{buckets: buckets}), do: buckets

  @doc """
  Adds node to routing table.
  """
  @spec refresh_node(t(), Node.t()) :: t()
  def refresh_node(
        table = %__MODULE__{current_node: %Node{key: key}},
        %Node{key: key}
      ),
      do: table

  def refresh_node(table = %__MODULE__{buckets: buckets}, node = %Node{}) do
    node_bucket_id = bucket_id(table, node)

    refresh_node_result =
      buckets
      |> Enum.at(node_bucket_id)
      |> Bucket.refresh_node(node)

    case refresh_node_result do
      {:full_bucket, candidate_for_removal, bucket} ->
        handle_full_bucket(table, bucket, candidate_for_removal, node)
        table

      {_descr, _node, bucket} ->
        replace_bucket(table, node_bucket_id, bucket)
    end
  end

  @doc """
  Returns neighbours of a specified node.
  """
  @spec neighbours(t(), Node.t()) :: [Node.t()]
  def neighbours(table = %__MODULE__{}, node = %Node{}) do
    bucket_idx = bucket_id(table, node)
    nearest_neighbors = nodes_at(table, bucket_idx)
    found_nodes = traverse(table, bucket_idx) ++ nearest_neighbors

    found_nodes
    |> Enum.sort_by(&Node.distance(&1, node))
    |> Enum.take(bucket_capacity())
  end

  @doc """
  Checks if node exists in routing table.
  """
  @spec member?(t(), Node.t()) :: boolean()
  def member?(%__MODULE__{buckets: buckets}, node = %Node{}) do
    buckets |> Enum.any?(&Bucket.member?(&1, node))
  end

  @doc """
  Returns bucket id that node belongs to in routing table.
  """
  @spec bucket_id(t(), Node.t()) :: integer()
  def bucket_id(%__MODULE__{current_node: current_node}, node = %Node{}) do
    node |> Node.common_prefix(current_node)
  end

  @spec replace_bucket(t(), integer(), Bucket.t()) :: t()
  defp replace_bucket(table, idx, bucket) do
    buckets =
      table.buckets
      |> List.replace_at(idx, bucket)

    %{table | buckets: buckets}
  end

  @spec bucket_at(t(), integer()) :: Bucket.t()
  defp bucket_at(%__MODULE__{buckets: buckets}, id) do
    Enum.at(buckets, id)
  end

  defp handle_full_bucket(_table, _bucket, _candidate_for_removal, _candidate_for_insertion) do
    # TODO
  end

  @spec traverse(t(), integer(), [Node.t()], integer()) :: [Node.t()]
  defp traverse(table, bucket_id, acc \\ [], step \\ 1) do
    left_boundary = bucket_id - step
    right_boundary = bucket_id + step
    is_out_of_left_boundary = left_boundary < 0
    is_out_of_right_boundary = right_boundary > buckets_count() - 1

    left_nodes = if is_out_of_left_boundary, do: [], else: table |> nodes_at(left_boundary)
    right_nodes = if is_out_of_right_boundary, do: [], else: table |> nodes_at(right_boundary)

    acc = acc ++ left_nodes ++ right_nodes

    if (is_out_of_left_boundary && is_out_of_right_boundary) ||
         Enum.count(acc) >= bucket_capacity() do
      acc
    else
      traverse(table, bucket_id, acc, step + 1)
    end
  end

  @spec initialize_buckets() :: [Bucket.t()]
  defp initialize_buckets() do
    1..buckets_count()
    |> Enum.map(fn num ->
      Bucket.new(num)
    end)
  end

  @spec nodes_at(t(), integer()) :: Node.t()
  defp nodes_at(table = %__MODULE__{}, bucket_id) do
    table
    |> bucket_at(bucket_id)
    |> Bucket.nodes()
  end

  @spec buckets_count() :: integer()
  defp buckets_count do
    KademliaConfig.id_size()
  end

  @spec bucket_capacity() :: integer()
  defp bucket_capacity do
    KademliaConfig.bucket_size()
  end
end
