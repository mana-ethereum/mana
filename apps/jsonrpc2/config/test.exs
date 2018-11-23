use Mix.Config

config :jsonrpc2,
  ipc: [enabled: false, path: Enum.join([System.user_home!(), "/.ethereum", "/mana.ipc"])],
  http: [enabled: false, port: 4000, interface: :local, max_connections: 10],
  ws: [enabled: false, port: 4000, interface: :local, max_connections: 10],
  bridge_mock: JSONRPC2.BridgeSyncMock
