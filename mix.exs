defmodule Exthereum.MixProject do
  use Mix.Project
  @root_path File.cwd!()

  def project do
    [
      apps_path: "apps",
      apps: [
        :abi,
        :blockchain,
        :evm,
        :ex_rlp,
        :ex_wire,
        :exth_crypto,
        :merkle_patricia_tree
      ],
      elixir: "~> 1.6.5",
      start_permanent: Mix.env() == :prod,
      dialyzer: [
        ignore_warnings: ".dialyzer.ignore-warnings",
        excluded_paths: [
          Path.join(@root_path, "_build/test/lib/abi/ebin"),
          Path.join(@root_path, "_build/test/lib/exth_crypto/ebin"),
          Path.join(@root_path, "_build/test/lib/ex_wire/ebin")
        ]
      ],
      deps: deps()
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    [
      {:dialyxir, "~> 0.5", only: [:dev, :test], runtime: false},
      {:ethereumex, "~> 0.3.2"},
    ]
  end
end
