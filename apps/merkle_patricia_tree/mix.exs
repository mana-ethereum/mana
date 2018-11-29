defmodule MerklePatriciaTree.Mixfile do
  use Mix.Project

  def project do
    [
      app: :merkle_patricia_tree,
      version: "0.2.6",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      description: "Ethereum's Merkle Patricia Trie data structure",
      package: [
        maintainers: ["Geoffrey Hayes", "Ayrat Badykov", "Mason Forest"],
        licenses: ["MIT", "Apache 2"],
        links: %{
          "GitHub" =>
            "https://github.com/mana-ethereum/mana/tree/master/apps/merkle_patricia_tree"
        }
      ],
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_options: [warnings_as_errors: true]
    ]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [extra_applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # To depend on another app inside the umbrella:
  #
  #   {:myapp, in_umbrella: true}
  #
  # Type `mix help deps` for more examples and options
  #
  defp deps do
    [
      {:ex_rlp, "~> 0.5.0"},
      {:exth_crypto, in_umbrella: true},
      {:rocksdb, "~> 0.23.2"},
      {:jason, "~> 1.1"}
    ]
  end
end
