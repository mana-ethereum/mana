use Mix.Config

config :ex_wire,
  network_adapter: {ExWire.Adapter.UDP, NetworkClient},
  sync: true,
  bootnodes: [
    "enode://04da7cd0359895a0d041c206aa7f6b192f1ebdbd0c897e66408c756776a9c399e9287c402658cec60be1d2d15179028df6f0c12788d894094ae5ac6fb0ba437c@127.0.0.1:30303"
  ],
  private_key:
    <<10, 122, 189, 137, 166, 190, 127, 238, 229, 16, 211, 182, 104, 78, 138, 37, 146, 116, 90,
      68, 76, 86, 168, 24, 200, 155, 0, 99, 58, 226, 211, 30>>,
  discovery: true,
  node_discovery: [
    network_adapter: {ExWire.Adapter.UDP, NetworkClient},
    kademlia_process_name: KademliaState,
    supervisor_name: ExWire.NodeDiscoverySupervisor,
    port: 30_366
  ]
