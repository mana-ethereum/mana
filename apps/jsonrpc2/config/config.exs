use Mix.Config

config :jsonrpc2,
  ipc: %{enabled: true, path: Enum.join([System.user_home!(), "/mana.ipc"])},
  http: %{enabled: true, port: 4000},
  ws: %{enabled: true, port: 4000},
  mana_version: String.trim(File.read!("MANA_VERSION"))

import_config "#{Mix.env()}.exs"
