use Mix.Config

config :jsonrpc2,
  ipc: %{enabled: true, path: Enum.join([System.user_home!(), "/.ethereum", "/mana.ipc"])},
  http: %{enabled: true, port: 4000},
  ws: %{enabled: true, port: 4000}

import_config "#{Mix.env()}.exs"
