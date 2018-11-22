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

mana_version =
  defer.(fn ->
    [app_root.(), "MANA_VERSION"]
    |> Path.join()
    |> File.read!()
    |> String.trim()
  end)

config :jsonrpc2,
  ipc: [enabled: true, path: Path.join([System.user_home!(), ".ethereum", "mana.ipc"])],
  http: [enabled: true, port: 3999, interface: :local],
  ws: [enabled: true, port: 4000, interface: :all],
  mana_version: mana_version

import_config "#{Mix.env()}.exs"
