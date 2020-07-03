use Mix.Config

defer = fn fun ->
  apply(fun, [])
end

app_root = fn ->
  if String.contains?(File.cwd!(), "apps") do
    Path.join([File.cwd!(), "/../../"])
  else
    File.cwd!()
  end
end

mana_version =
  defer.(fn ->
    [app_root.(), "MANA_VERSION"]
    |> Path.join()
    |> File.read!()
    |> String.trim()
  end)

config :jsonrpc2,
  ipc: [enabled: true, path: Path.join([System.user_home!(), ".ethereum", "mana.ipc"])],
  http: [enabled: true, port: 8545, interface: :local, max_connections: 10],
  ws: [enabled: true, port: 8545, interface: :local, max_connections: 10],
  mana_version: mana_version

import_config "#{Mix.env()}.exs"
