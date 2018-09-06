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
  # If you are running Phoenix, you should make sure that
  # server: true is set and the code reloader is disabled,
  # even in dev mode.
  # It is recommended that you build with MIX_ENV=prod and pass
  # the --env flag to Distillery explicitly if you want to use
  # dev mode.
  set dev_mode: true
  set include_erts: false
  set cookie: :")Sos6$ufe_J[V8v<}wkg$[SsQU3Mb1IYy$Z0@jc1vuif*ddYRu7aAb|jl(R]9r*4"
end

environment :prod do
  set include_erts: true
  set include_src: false
  set cookie: :"kc!fg?t8,UF5)GHre*=<5/I$N`m`PJ3!3xUiw<?FIP8ZRbuY;18hjhPo)=se8`j}"
end

# You may define one or more releases in this file.
# If you have not set a default release, or selected one
# when running `mix release`, the first release in the file
# will be used by default

release :mana do
  set version: "0.1.0"
  set applications: [
    :runtime_tools,
    blockchain: :permanent,
    evm: :permanent,
    ex_wire: :permanent,
    exth_crypto: :permanent,
    merkle_patricia_tree: :permanent
  ]
end

