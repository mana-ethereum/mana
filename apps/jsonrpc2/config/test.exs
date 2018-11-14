use Mix.Config

config :jsonrpc2,
  ipc: [enabled: false, path: Enum.join([System.user_home!(), "/.ethereum", "/mana.ipc"])],
  http: [enabled: false, port: 4000],
  ws: [enabled: false, port: 4000]
