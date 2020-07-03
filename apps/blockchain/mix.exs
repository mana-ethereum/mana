defmodule Blockchain.Mixfile do
  use Mix.Project

  def project do
    [
      app: :blockchain,
      version: "0.1.7",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      description: "Ethereum's Blockchain Manager",
      package: [
        maintainers: ["Ayrat Badykov", "Mason Forest"],
        licenses: ["MIT", "Apache 2"],
        links: %{"GitHub" => "https://github.com/mana-ethereum/mana/tree/master/apps/blockchain"}
      ],
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [warnings_as_errors: true]
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [
      applications: [:ethereumex],
      extra_applications: [:logger, :logger_file_backend],
      mod: {Blockchain.Application, []}
    ]
  end

  defp deps do
    [
      # External deps
      {:ethereumex, "~> 0.5.0"},
      {:ex_rlp, "~> 0.5.2"},
      {:logger_file_backend, "~> 0.0.10"},
      # Umbrella deps
      {:evm, in_umbrella: true},
      {:exth, in_umbrella: true},
      {:exth_crypto, in_umbrella: true},
      {:merkle_patricia_tree, in_umbrella: true}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
