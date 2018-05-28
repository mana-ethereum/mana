use Mix.Config

config :ex_wire,
  private_key:
    <<10, 122, 189, 137, 166, 190, 127, 238, 229, 16, 211, 182, 104, 78, 138, 37, 146, 116, 90,
      68, 76, 86, 168, 24, 200, 155, 0, 99, 58, 226, 211, 30>>,
  node_discovery: [
    network_adapter: {ExWire.Adapter.Test, :test_network_adapter},
    kademlia_process_name: KademliaState,
    supervisor_name: ExWire.NodeDiscoverySupervisor,
    port: 30_304
  ]
