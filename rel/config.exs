# Import all plugins from `rel/plugins`
# They can then be used by adding `plugin MyPlugin` to
# either an environment, or release definition, where
# `MyPlugin` is the name of the plugin module.
~w(rel plugins *.exs)
|> Path.join()
|> Path.wildcard()
|> Enum.map(&Code.eval_file(&1))

use Mix.Releases.Config,
  # This sets the default release built by `mix release`
  default_release: :default,
  # This sets the default environment used by `mix release`
  default_environment: Mix.env()

# For a full list of config options for both releases
# and environments, visit https://hexdocs.pm/distillery/config/distillery.html

# You may define one or more environments in this file,
# an environment's settings will override those of a release
# when building in that environment, this combination of release
# and environment configuration is called a profile

environment :dev do
  set(
    commands: [
      # we can replace sync with whatever, 'run' too for example
      sync: "rel/commands/sync",
      run: "rel/commands/sync"
    ]
  )

  set(dev_mode: true)
  set(include_erts: true)

  set(
    cookie:
      apply(
        fn ->
          cookie_path =
            case String.contains?(System.cwd!(), "apps") do
              true ->
                Path.join(["../../", "COOKIE"])

              false ->
                Path.join([System.cwd!(), "COOKIE"])
            end

          cookie =
            :crypto.strong_rand_bytes(32)
            |> Base.encode32()

          :ok = File.write!(cookie_path, cookie)
          :erlang.binary_to_atom(cookie, :utf8)
        end,
        []
      )
  )
end

environment :prod do
  set(include_erts: true)
  set(include_src: false)
  set(cookie: :"Wxv5K^qhnRXWBRLt0R/V_$u3!(Hz~Um%U5MrXVJzpvb,{43bHM8G*0:RokSbah]%")
end

# You may define one or more releases in this file.
# If you have not set a default release, or selected one
# when running `mix release`, the first release in the file
# will be used by default

release :mana do
  set(
    version:
      apply(
        fn ->
          case String.contains?(System.cwd!(), "apps") do
            true ->
              String.trim(File.read!(Path.join(["../../", "MANA_VERSION"])))

            false ->
              String.trim(File.read!(Path.join([System.cwd!(), "MANA_VERSION"])))
          end
        end,
        []
      )
  )

  set(
    applications: [
      :runtime_tools,
      blockchain: :permanent,
      cli: :permanent,
      evm: :permanent,
      ex_wire: :permanent,
      exth_crypto: :permanent,
      merkle_patricia_tree: :permanent,
      jsonrpc2: :permanent
    ]
  )
end
