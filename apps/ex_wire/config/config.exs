# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

defer = fn fun ->
  apply(fun, [])
end

app_root = fn ->
  if String.contains?(System.cwd!(), "apps") do
    Path.join([System.cwd!(), "/../../"])
  else
    System.cwd!()
  end
end

db_root = defer.(fn -> Path.join([app_root.(), "/db"]) end)

mana_version =
  defer.(fn ->
    [app_root.(), "MANA_VERSION"]
    |> Path.join()
    |> File.read!()
    |> String.trim()
  end)

config :ex_wire,
  p2p_version: 0x04,
  protocol_version: 63,
  caps: [{"eth", 62}, {"eth", 63}, {"par", 1}],
  # TODO: This should be set and stored in a file
  private_key: :random,
  bootnodes: :from_chain,
  # Number of peer advertisements before we trust a block
  commitment_count: 1,
  discovery: true,
  node_discovery: [
    network_adapter: {ExWire.Adapter.UDP, NetworkClient},
    supervisor_name: ExWire.NodeDiscoverySupervisor,
    port: 30_304
  ],
  db_root: db_root,
  mana_version: mana_version,
  warp: false

config :ex_wire, :environment, Mix.env()
import_config "#{Mix.env()}.exs"
