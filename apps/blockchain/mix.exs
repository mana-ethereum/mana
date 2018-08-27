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
        licenses: ["LGPL v3"],
        links: %{"GitHub" => "https://github.com/poanetwork/mana/apps/blockchain"}
      ],
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [
      applications: [:ethereumex],
      extra_applications: [:logger],
      mod: {Blockchain.Application, []}
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # To depend on another app inside the umbrella:
  #
  #   {:my_app, in_umbrella: true}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:credo, "~>  0.9.1", only: [:dev, :test], runtime: false},
      {:ethereumex, "~> 0.3.2"},
      {:evm, in_umbrella: true},
      {:ex_rlp, "~> 0.3.0"},
      {:exth_crypto, in_umbrella: true},
      {:merkle_patricia_tree, in_umbrella: true},
      {:poison, "~> 3.1.0"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
