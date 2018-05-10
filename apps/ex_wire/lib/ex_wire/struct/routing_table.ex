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
  Adds node to routing table.
  """
  @spec add_node(t(), Peer.t()) :: t()
  def add_node(
        table = %__MODULE__{current_node: %Peer{remote_id: current_node_id}},
        %Peer{remote_id: current_node_id}
      ),
      do: table

  def add_node(table = %__MODULE__{}, node = %Peer{}) do
    bucket_idx = node |> Peer.common_prefix(table.current_node)

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
  def neighbours(%__MODULE__{buckets: buckets}, node = %Peer{}) do
    buckets
    |> Enum.flat_map(fn bucket ->
      bucket.nodes
    end)
    |> Enum.sort_by(&Peer.distance(&1, node))
    |> Enum.take(KademliaConfig.bucket_size())
  end

  @doc """
  Checks if node exists in routing table.
  """
  @spec member?(t(), Peer.t()) :: boolean()
  def member?(%__MODULE__{buckets: buckets}, peer = %Peer{}) do
    buckets |> Enum.any?(&Bucket.member?(&1, peer))
  end

  @spec replace_bucket(t(), integer(), Bucket.t()) :: t()
  defp replace_bucket(table, idx, bucket) do
    buckets =
      table.buckets
      |> List.replace_at(idx, bucket)

    %{table | buckets: buckets}
  end

  defp handle_full_bucket(_table, _bucket, _candidate_for_removal, _candidate_for_insertion) do
    # TODO
  end

  @spec initialize_buckets() :: [Bucket.t()]
  defp initialize_buckets() do
    1..KademliaConfig.id_size()
    |> Enum.map(fn num ->
      Bucket.new(num)
    end)
  end
end
