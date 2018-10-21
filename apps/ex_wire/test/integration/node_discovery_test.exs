defmodule ExWire.NodeDiscoveryTest do
  use ExUnit.Case, async: true
  alias ExWire.Adapter.UDP
  alias ExWire.{Config, Kademlia, Network}
  alias ExWire.Kademlia.{Node, RoutingTable}
  alias ExWire.Message.FindNeighbours
  alias ExWire.NodeDiscoverySupervisor
  alias ExWire.Struct.Endpoint

  @moduletag integration: true
  @moduletag network: true

  @remote_address System.get_env("REMOTE_TEST_PEER") || ExWire.Config.chain().nodes |> List.last()
  @bootnodes [
    "enode://6332792c4a00e3e4ee0926ed89e0d27ef985424d97b6a45bf0f23e51f0dcb5e66b875777506458aea7af6f9e4ffb69f43f3778ee73c81ed9d34c51c4b16b0b0f@52.232.243.152:30303",
    "enode://94c15d1b9e2fe7ce56e458b9a3b672ef11894ddedd0c6f247e0f1d3487f52b66208fb4aeb8179fce6e3a749ea93ed147c37976d67af557508d199d9594c35f09@192.81.208.223:30303",
    "enode://30b7ab30a01c124a6cceca36863ece12c4f5fa68e3ba9b0b51407ccc002eeed3b3102d20a88f1c1d3c3154e2449317b8ef95090e77b312d5cc39354f86d5d606@52.176.7.10:30303",
    "enode://865a63255b3bb68023b6bffd5095118fcc13e79dcf014fe4e47e065c350c7cc72af2e53eff895f11ba1bbb6a2b33271c1116ee870f266618eadfc2e78aa7349c@52.176.100.77:30303"
  ]

  setup_all do
    kademlia_process_name = KademliaNodeDiscoveryTest
    udp_name = UdpNodeDiscoveryTest
    network_adapter = {UDP, udp_name}
    supervisor_name = NodeDiscoveryTest
    port = 11_117

    start_supervised!({
      NodeDiscoverySupervisor,
      [
        kademlia_process_name: kademlia_process_name,
        network_adapter: network_adapter,
        supervisor_name: supervisor_name,
        port: port,
        nodes: @bootnodes
      ]
    })

    {:ok,
     %{
       kademlia_name: kademlia_process_name,
       supervisor_name: supervisor_name,
       udp_name: udp_name
     }}
  end

  test "receives pong from remote node and adds it to local routing table", %{
    kademlia_name: kademlia_name
  } do
    expected_node = expected_node()
    Kademlia.ping(expected_node, process_name: kademlia_name)

    Process.sleep(1_000)

    routing_table = Kademlia.routing_table(process_name: kademlia_name)
    assert RoutingTable.member?(routing_table, expected_node())
  end

  test "request neighbours from remote node and pings received nodes", %{
    kademlia_name: kademlia_name,
    udp_name: udp_name
  } do
    find_neighbours = FindNeighbours.new(Config.node_id())

    Network.send(find_neighbours, udp_name, remote_endpoint())

    Process.sleep(2_000)

    routing_table = Kademlia.routing_table(process_name: kademlia_name)
    pings_count = routing_table.expected_pongs |> Map.values() |> Enum.count()

    assert pings_count > 0
  end

  test "successfully finished discovery and adds nodes to routing_table", %{
    kademlia_name: kademlia_name
  } do
    # let's wait for all discovery rounds
    Process.sleep(30_000)

    nodes_count =
      Kademlia.routing_table(process_name: kademlia_name).buckets
      |> Enum.flat_map(fn bucket -> bucket.nodes end)
      |> Enum.count()

    assert nodes_count > Enum.count(@bootnodes)
  end

  defp remote_endpoint do
    %URI{
      scheme: _scheme,
      userinfo: _remote_id,
      host: remote_host,
      port: remote_peer_port
    } = remote_uri()

    remote_ip =
      with {:ok, remote_ip} <- :inet.ip(remote_host |> String.to_charlist()) do
        remote_ip |> Tuple.to_list()
      end

    %Endpoint{
      ip: remote_ip,
      udp_port: remote_peer_port
    }
  end

  defp expected_node do
    %URI{
      scheme: _scheme,
      userinfo: remote_id,
      host: _remote_host,
      port: _remote_peer_port
    } = remote_uri()

    public_key = ExthCrypto.Math.hex_to_bin(remote_id)

    Node.new(public_key, remote_endpoint())
  end

  defp remote_uri do
    %URI{
      scheme: "enode",
      userinfo: _remote_id,
      host: _remote_host,
      port: _remote_peer_port
    } = uri = URI.parse(@remote_address)

    uri
  end
end
