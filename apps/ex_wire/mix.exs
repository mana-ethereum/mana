defmodule ExWire.Mixfile do
  use Mix.Project

  def project do
    [
      app: :ex_wire,
      version: "0.1.1",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      description: "Elixir Client for Ethereum's RLPx, DevP2P and Eth Wire Protocol",
      package: [
        maintainers: ["Mason Fischer", "Geoffrey Hayes", "Ayrat Badykov"],
        licenses: ["MIT", "Apache 2"],
        links: %{"GitHub" => "https://github.com/mana-ethereum/mana/tree/master/apps/ex_wire"}
      ],
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_options: [warnings_as_errors: true]
    ]
  end

  def application do
    [mod: {ExWire, []}, extra_applications: [:logger, :logger_file_backend]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # External deps
      {:binary, "~> 0.0.5"},
      {:ex_doc, "~> 0.16", only: :dev, runtime: false},
      {:ex_rlp, "~> 0.5.2"},
      {:snappyer, "~> 1.2"},
      {:logger_file_backend, "~> 0.0.10"},
      # Umbrella deps
      {:blockchain, in_umbrella: true},
      {:exth, in_umbrella: true},
      {:exth_crypto, "~> 0.1.6"},
      {:evm, in_umbrella: true}
    ]
  end
end
