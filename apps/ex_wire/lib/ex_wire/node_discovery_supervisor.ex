defmodule ExWire.NodeDiscoverySupervisor do
  @moduledoc """
  The Node Discovery Supervisor manages two processes. The first process is kademlia
  algorithm's routing table state - ExWire.Kademlia.Server,  the second one is process
  that sends and receives all messages that are used for node discovery (ping, pong etc).
  """
  use Supervisor

  alias ExWire.{Config, Network}
  alias ExWire.Kademlia.Node
  alias ExWire.Kademlia.Server, as: KademliaServer
  alias ExWire.Struct.Endpoint

  def start_link(params \\ []) do
    supervisor_name = Keyword.get(params, :supervisor_name, __MODULE__)

    Supervisor.start_link(__MODULE__, params, name: supervisor_name)
  end

  def init(params) do
    kademlia_name = Keyword.get(params, :kademlia_process_name, KademliaState)

    {udp_module, udp_process_name} = ExWire.Config.udp_network_adapter(params)
    port = ExWire.Config.listen_port(params)

    bootnodes =
      Config.bootnodes(params)
      |> Enum.map(&Node.new/1)

    children = [
      {KademliaServer,
       [
         name: kademlia_name,
         current_node: current_node(params),
         network_client_name: udp_process_name,
         nodes: bootnodes
       ]},
      {udp_module,
       [
         name: udp_process_name,
         network_module: {Network, [kademlia_process_name: kademlia_name]},
         port: port
       ]}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end

  @spec current_node(Keyword.t()) :: ExWire.Kademlia.Node.t()
  def current_node(params) do
    udp_port = Config.listen_port(params)
    public_ip = Config.public_ip(params)
    public_key = Config.node_id()
    endpoint = %Endpoint{ip: public_ip, udp_port: udp_port}

    Node.new(public_key, endpoint)
  end
end
