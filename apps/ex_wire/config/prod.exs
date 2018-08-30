use Mix.Config

config :ex_wire,
  db_path: "db/mana-prod",
  network_adapter: {ExWire.Adapter.UDP, NetworkClient},
  sync: true,
  discovery: true,
  node_discovery: [
    network_adapter: {ExWire.Adapter.UDP, NetworkClient},
    kademlia_process_name: KademliaState,
    supervisor_name: ExWire.NodeDiscoverySupervisor,
    port: 30_304
  ]
