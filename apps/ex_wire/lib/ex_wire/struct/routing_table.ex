defmodule ExWire.Struct.RoutingTable do
  @moduledoc """
  Module for working with current node's buckets
  """

  alias ExWire.Struct.{Bucket, Peer}
  alias ExWire.KademliaConfig

  @network Application.fetch_env(:ex_wire, :network_process_name)

  defstruct [:current_node, :buckets]

  @type t :: %__MODULE__{
          current_node: Peer.t(),
          buckets: [Bucket.t()]
        }

  @doc """
  Creates new routing table.

  ## Examples

      iex> node = ExWire.Struct.Peer.new("13.84.180.240", 30303, "6ce05930c72abc632c58e2e4324f7c7ea478cec0ed4fa2528982cf34483094e9cbc9216e7aa349691242576d552a2a56aaeae426c5303ded677ce455ba1acd9d", time: :test)
      iex> table = node |> ExWire.Struct.RoutingTable.new()
      iex> table.buckets |> Enum.count
      256
  """
  @spec new(Peer.t()) :: t()
  def new(peer = %Peer{}) do
    initial_buckets = initialize_buckets()

    %__MODULE__{
      current_node: peer,
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
  @spec add_node(t(), Peer.t()) :: t()
  def add_node(
        table = %__MODULE__{current_node: %Peer{remote_id: current_node_id}},
        %Peer{remote_id: current_node_id}
      ),
      do: table

  def add_node(table = %__MODULE__{}, node = %Peer{}) do
    bucket_idx = table |> bucket_id(node)

    case table.buckets |> Enum.at(bucket_idx) |> Bucket.add_node(node) do
      {:full_bucket, candidate_for_removal, bucket} ->
        handle_full_bucket(table, bucket, candidate_for_removal, node)
        table

      {_descr, _node, bucket} ->
        replace_bucket(table, bucket_idx, bucket)
    end
  end

  @doc """
  Returns neighbours of a specified node.
  """
  @spec neighbours(t(), Peer.t()) :: [Peer.t()]
  def neighbours(table = %__MODULE__{}, node = %Peer{}) do
    bucket_idx = bucket_id(table, node)
    similar_to_current_node = table |> nodes_at(bucket_idx)
    found_nodes = traverse(table, bucket_idx) ++ similar_to_current_node

    found_nodes
    |> Enum.sort_by(&Peer.distance(&1, node))
    |> Enum.take(bucket_size())
  end

  @doc """
  Checks if node exists in routing table.
  """
  @spec member?(t(), Peer.t()) :: boolean()
  def member?(%__MODULE__{buckets: buckets}, peer = %Peer{}) do
    buckets |> Enum.any?(&Bucket.member?(&1, peer))
  end

  @doc """
  Returns bucket id that node belongs to in routing table.
  """
  @spec bucket_id(t(), Peer.t()) :: integer()
  def bucket_id(%__MODULE__{current_node: current_node}, node = %Peer{}) do
    node |> Peer.common_prefix(current_node)
  end

  @spec replace_bucket(t(), integer(), Bucket.t()) :: t()
  defp replace_bucket(table, idx, bucket) do
    buckets =
      table.buckets
      |> List.replace_at(idx, bucket)

    %{table | buckets: buckets}
  end

  @spec nodes_at(t(), integer()) :: Peer.t()
  defp nodes_at(table = %__MODULE__{}, bucket_id) do
    table
    |> bucket_at(bucket_id)
    |> Bucket.nodes()
  end

  @spec bucket_at(t(), integer()) :: Bucket.t()
  defp bucket_at(%__MODULE__{buckets: buckets}, id) do
    buckets |> Enum.at(id)
  end

  defp handle_full_bucket(_table, _bucket, _candidate_for_removal, _candidate_for_insertion) do
    # TODO
  end

  @spec traverse(t(), integer(), [Peer.t()], integer()) :: [Peer.t()]
  defp traverse(table, bucket_id, acc \\ [], step \\ 1) do
    is_out_of_left_boundary = bucket_id - step < 0
    is_out_of_right_boundary = bucket_id + step > bucket_size() - 1

    left_nodes = if is_out_of_left_boundary, do: [], else: table |> nodes_at(bucket_id - step)
    right_nodes = if is_out_of_right_boundary, do: [], else: table |> nodes_at(bucket_id + step)

    acc = acc ++ left_nodes ++ right_nodes

    if (is_out_of_left_boundary && is_out_of_right_boundary) || Enum.count(acc) >= bucket_size() do
      acc
    else
      traverse(table, bucket_id, acc, step + 1)
    end
  end

  @spec initialize_buckets() :: [Bucket.t()]
  defp initialize_buckets() do
    1..bucket_size()
    |> Enum.map(fn num ->
      Bucket.new(num)
    end)
  end

  @spec bucket_size() :: integer()
  defp bucket_size do
    KademliaConfig.id_size()
  end
end
