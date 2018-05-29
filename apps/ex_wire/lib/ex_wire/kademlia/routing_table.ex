defmodule ExWire.Kademlia.RoutingTable do
  @moduledoc """
  Module for working with current node's buckets
  """

  alias ExWire.Kademlia.{Bucket, Node}
  alias ExWire.Kademlia.Config, as: KademliaConfig
  alias ExWire.Message.{Ping, Pong, FindNeighbours, Neighbours}
  alias ExWire.{Network, Protocol}
  alias ExWire.Util.Timestamp
  alias ExWire.Handler.Params
  alias ExWire.Struct.Endpoint

  defstruct [
    :current_node,
    :buckets,
    :network_client_name,
    :expected_pongs,
    :discovery_nodes,
    :discovery_round
  ]

  @type expected_pongs :: %{required(binary()) => {Node.t(), Node.t()}}
  @type t :: %__MODULE__{
          current_node: Node.t(),
          buckets: [Bucket.t()],
          network_client_name: pid() | atom(),
          expected_pongs: expected_pongs(),
          discovery_nodes: [Node.t()],
          discovery_round: integer()
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
      ...>    157>>,
      ...>  endpoint: %ExWire.Struct.Endpoint{
      ...>    ip: [1, 2, 3, 4],
      ...>    tcp_port: 5,
      ...>    udp_port: nil
      ...>  }
      ...> }
      iex> {:ok, network_client_pid} = ExWire.Adapter.UDP.start_link(network_module: {ExWire.Network, []}, port: 35351, name: :doctest)
      iex> table = ExWire.Kademlia.RoutingTable.new(node, network_client_pid)
      iex> table.buckets |> Enum.count
      256
  """
  @spec new(Node.t(), pid() | atom()) :: t()
  def new(node = %Node{}, client_pid) do
    initial_buckets = initialize_buckets()

    %__MODULE__{
      current_node: node,
      buckets: initial_buckets,
      network_client_name: client_pid,
      expected_pongs: %{},
      discovery_nodes: [],
      discovery_round: 0
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
      {:full_bucket, candidate_for_removal, _bucket} ->
        ping(table, candidate_for_removal, node)

      {_descr, _node, bucket} ->
        replace_bucket(table, node_bucket_id, bucket)
    end
  end

  @doc """
  Removes a node from routing table.
  """
  @spec remove_node(t(), Node.t()) :: t()
  def remove_node(table = %__MODULE__{}, node = %Node{}) do
    node_bucket_id = bucket_id(table, node)

    updated_bucket =
      table
      |> bucket_at(node_bucket_id)
      |> Bucket.remove_node(node)

    replace_bucket(table, node_bucket_id, updated_bucket)
  end

  @doc """
  Returns neighbours of a specified node.
  """
  @spec neighbours(t(), FindNeighbours.t(), Endpoint.t()) :: [Node.t()]
  def neighbours(
        table = %__MODULE__{},
        %FindNeighbours{target: public_key, timestamp: timestamp},
        endpoint
      ) do
    if timestamp < Timestamp.now() do
      []
    else
      node = Node.new(public_key, endpoint)
      bucket_idx = bucket_id(table, node)
      nearest_neighbors = nodes_at(table, bucket_idx)

      found_nodes =
        traverse(table, bucket_id: bucket_idx, number: bucket_capacity()) ++ nearest_neighbors

      found_nodes
      |> Enum.sort_by(&Node.common_prefix(&1, node), &>=/2)
      |> Enum.take(bucket_capacity())
    end
  end

  @doc """
  Returns current node's discovery nodes. Basically it just finds the closest to current node
  nodes and filters nodes that were already used for node discovery.
  """
  @spec discovery_nodes(t()) :: [Node.t()]
  def discovery_nodes(table) do
    filter = fn node ->
      !Enum.member?(table.discovery_nodes, node)
    end

    nodes_number = KademliaConfig.concurrency()
    closest_bucket_id = buckets_count() - 1
    travers_opts = [bucket_id: closest_bucket_id, filter: filter, number: nodes_number]

    nearest_neighbors = nodes_at(table, closest_bucket_id)
    found_nodes = traverse(table, travers_opts) ++ nearest_neighbors

    found_nodes
    |> Enum.sort_by(&Node.common_prefix(&1, table.current_node), &>=/2)
    |> Enum.take(nodes_number)
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

  @doc """
  Pings a node saving it to expected pongs.
  """
  @spec ping(t(), Node.t()) :: Network.handler_action()
  def ping(
        table = %__MODULE__{
          current_node: %Node{endpoint: current_endpoint},
          network_client_name: network_client_name
        },
        node = %Node{endpoint: remote_endpoint},
        replace_candidate \\ nil
      ) do
    ping = Ping.new(current_endpoint, remote_endpoint)
    {:sent_message, _, encoded_message} = Network.send(ping, network_client_name, remote_endpoint)

    mdc = Protocol.message_mdc(encoded_message)
    updated_pongs = Map.put(table.expected_pongs, mdc, {node, replace_candidate})

    %{table | expected_pongs: updated_pongs}
  end

  @doc """
  Handles Pong message.

   There are three cases:
   - If we were waiting for this pong (it's stored in routing table) and it's not expired,
       we refresh stale node.
   - If a pong is expired, we do nothing.
  """
  @spec handle_pong(t(), Pong.t()) :: t()
  def handle_pong(
        table = %__MODULE__{expected_pongs: pongs},
        %Pong{hash: hash, timestamp: timestamp}
      ) do
    {node, updated_pongs} = Map.pop(pongs, hash)

    table = %{table | expected_pongs: updated_pongs}

    if timestamp > Timestamp.now() do
      case node do
        {removal_candidate, _insertion_candidate} ->
          refresh_node(table, removal_candidate)

        _ ->
          table
      end
    else
      table
    end
  end

  @spec handle_ping(t(), Params.t()) :: t()
  def handle_ping(table, params) do
    add_node_from_params(table, params)
  end

  @spec handle_neighbours(t(), Neighbours.t()) :: :ok
  def handle_neighbours(table, %Neighbours{timestamp: timestamp, nodes: nodes}) do
    if timestamp > Timestamp.now() do
      nodes
      |> Enum.map(fn neighbour ->
        Node.new(neighbour.node, neighbour.endpoint)
      end)
      |> Enum.reject(&member?(table, &1))
      |> Enum.reduce(table, fn node, acc ->
        ping(acc, node)
      end)
    else
      table
    end
  end

  @spec replace_bucket(t(), integer(), Bucket.t()) :: t()
  def replace_bucket(table, idx, bucket) do
    buckets =
      table.buckets
      |> List.replace_at(idx, bucket)

    %{table | buckets: buckets}
  end

  @spec add_node_from_params(t(), Params.t()) :: t()
  defp add_node_from_params(table, params) do
    node = Node.from_handler_params(params)

    refresh_node(table, node)
  end

  @spec bucket_at(t(), integer()) :: Bucket.t()
  defp bucket_at(%__MODULE__{buckets: buckets}, id) do
    Enum.at(buckets, id)
  end

  @spec traverse(t(), Keyword.t()) :: [Node.t()]
  defp traverse(table, opts) do
    bucket_id = Keyword.fetch!(opts, :bucket_id)
    acc = opts[:acc] || []
    step = opts[:step] || 1
    required_nodes = opts[:number] || bucket_capacity()
    filter_function = opts[:filter]

    left_boundary = bucket_id - step
    right_boundary = bucket_id + step
    is_out_of_left_boundary = left_boundary < 0
    is_out_of_right_boundary = right_boundary > buckets_count() - 1

    left_nodes = if is_out_of_left_boundary, do: [], else: table |> nodes_at(left_boundary)
    right_nodes = if is_out_of_right_boundary, do: [], else: table |> nodes_at(right_boundary)
    found_nodes = left_nodes ++ right_nodes

    filtered_nodes =
      if filter_function,
        do: Enum.filter(found_nodes, fn el -> filter_function.(el) end),
        else: found_nodes

    acc = acc ++ filtered_nodes

    if (is_out_of_left_boundary && is_out_of_right_boundary) || Enum.count(acc) > required_nodes do
      acc
    else
      opts =
        opts
        |> Keyword.put(:step, step + 1)
        |> Keyword.put(:acc, acc)

      traverse(table, opts)
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
  def nodes_at(table = %__MODULE__{}, bucket_id) do
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
