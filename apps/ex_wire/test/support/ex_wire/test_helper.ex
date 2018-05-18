defmodule ExWire.TestHelper do
  @moduledoc """
    Helper methods shared across test files.
  """

  alias ExWire.Kademlia.{Node, RoutingTable, Bucket}
  alias ExWire.Kademlia.Config, as: KademliaConfig
  alias ExWire.Adapter.UDP
  alias ExWire.Network

  def random_routing_table(opts \\ []) do
    port = opts[:port] || random(9_999)

    {:ok, network_client_pid} =
      UDP.start_link(network_module: {Network, []}, port: port, name: :test)

    table = random_node() |> RoutingTable.new(network_client_pid)

    1..(KademliaConfig.bucket_size() * KademliaConfig.id_size())
    |> Enum.reduce(table, fn _el, acc ->
      RoutingTable.refresh_node(acc, random_node())
    end)
  end

  def random_node do
    Node.new(public_key(), random_endpoint())
  end

  def random_endpoint do
    ExWire.Struct.Endpoint.decode([random_ip(), random_port(), random_port()])
  end

  def random_bucket(opts \\ []) do
    id = opts[:id] || 1
    bucket_size = opts[:bucket_size] || KademliaConfig.bucket_size()

    1..bucket_size
    |> Enum.reduce(Bucket.new(id), fn _el, acc ->
      Bucket.insert_node(acc, random_node())
    end)
  end

  def random(limit) do
    :rand.uniform(limit)
  end

  defp public_key do
    1..64
    |> Enum.reduce(<<>>, fn _el, acc ->
      random = random(256)

      acc <> <<random>>
    end)
  end

  defp random_ip do
    1..4
    |> Enum.reduce(<<>>, fn _el, acc ->
      random = random(255)

      acc <> <<random>>
    end)
  end

  defp random_port do
    <<random(99_999)>>
  end
end
