use Mix.Config

config :jsonrpc2,
  ipc: [enabled: true, path: Enum.join([System.user_home!(), "/.ethereum", "/mana.ipc"])],
  http: [enabled: true, port: 4000],
  ws: [enabled: true, port: 4000],
  mana_version:
    :erlang.apply(
      fn ->
        case String.contains?(System.cwd!(), "apps") do
          true ->
            String.trim(File.read!(Enum.join(["../../", "MANA_VERSION"])))

          false ->
            String.trim(File.read!(Enum.join([System.cwd!(), "/MANA_VERSION"])))
        end
      end,
      []
    )

import_config "#{Mix.env()}.exs"
