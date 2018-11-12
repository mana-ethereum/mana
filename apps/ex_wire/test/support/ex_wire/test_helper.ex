defmodule ExWire.TestHelper do
  @moduledoc """
    Helper methods shared across test files.
  """

  alias ExWire.Adapter.UDP
  alias ExWire.Kademlia.Config, as: KademliaConfig
  alias ExWire.Kademlia.{Bucket, Node, RoutingTable}
  alias ExWire.Network
  alias ExWire.Struct.Endpoint

  def random_routing_table(opts \\ []) do
    port = opts[:port] || random_port_number()

    {:ok, network_client_pid} =
      UDP.start_link(
        String.to_atom("test#{random(1_000)}"),
        {Network, []},
        port
      )

    table = random_node() |> RoutingTable.new(network_client_pid)

    1..(KademliaConfig.bucket_size() * KademliaConfig.id_size())
    |> Enum.reduce(table, fn _el, acc ->
      RoutingTable.refresh_node(acc, random_node())
    end)
  end

  def random_empty_table do
    {:ok, network_client_pid} =
      UDP.start_link(
        :routing_table_test,
        {Network, []},
        random_port_number()
      )

    RoutingTable.new(random_node(), network_client_pid)
  end

  def random_node do
    Node.new(public_key(), random_endpoint())
  end

  def random_endpoint do
    %Endpoint{
      ip: random_ip(),
      udp_port: random_port_number(),
      tcp_port: random_port_number()
    }
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
    |> Enum.reduce([], fn _el, acc ->
      random = random(255)

      acc ++ [random]
    end)
  end

  def random_port_number do
    Enum.random(49_152..65_535)
  end
end
