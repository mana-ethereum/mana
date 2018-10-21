defmodule ExWire.NodeDiscoverySupervisor do
  use Supervisor

  @moduledoc """
  The Node Discovery Supervisor manages two processes. The first process is kademlia
  algorithm's routing table state - ExWire.Kademlia.Server,  the second one is process
  that sends and receives all messages that are used for node discovery (ping, pong etc)
  """

  alias ExWire.{Config, Network}
  alias ExWire.Kademlia.Node
  alias ExWire.Kademlia.Server, as: KademliaServer
  alias ExWire.Struct.Endpoint

  def start_link(params \\ []) do
    supervisor_name = discovery_param(params, :supervisor_name)

    Supervisor.start_link(__MODULE__, params, name: supervisor_name)
  end

  def init(params) do
    {udp_module, udp_process_name} = discovery_param(params, :network_adapter)
    kademlia_name = discovery_param(params, :kademlia_process_name)
    port = discovery_param(params, :port)
    bootnodes = (params[:nodes] || nodes()) |> Enum.map(&Node.new/1)

    children = [
      {KademliaServer,
       [
         name: kademlia_name,
         current_node: current_node(),
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

  def current_node do
    udp_port = Config.listen_port()
    public_ip = Config.public_ip()
    public_key = Config.node_id()
    endpoint = %Endpoint{ip: public_ip, udp_port: udp_port}

    Node.new(public_key, endpoint)
  end

  defp discovery_param(params, key) do
    params[key] || default_discovery_params()[key]
  end

  defp default_discovery_params do
    Config.node_discovery_params()
  end

  defp nodes do
    if Mix.env() == :test do
      []
    else
      Config.bootnodes()
    end
  end
end
