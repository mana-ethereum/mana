defmodule ExWire.TestHelper do
  @moduledoc """
    Helper methods shared across test files.
  """

  alias ExWire.Kademlia.{Node, RoutingTable}
  alias ExWire.Kademlia.Config, as: KademliaConfig

  def random_routing_table do
    table = random_node() |> RoutingTable.new()

    1..(KademliaConfig.bucket_size() * KademliaConfig.id_size())
    |> Enum.reduce(table, fn _el, acc ->
      RoutingTable.refresh_node(acc, random_node())
    end)
  end

  def random_node do
    Node.new(public_key(), random_endpoint())
  end

  def random_endpoint do
    ExWire.Struct.Endpoint.decode([random_ip(), random_port(), random_ip()])
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

  defp random(limit) do
    :rand.uniform(limit)
  end
end
