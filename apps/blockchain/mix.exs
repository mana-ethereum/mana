defmodule Blockchain.Mixfile do
  use Mix.Project

  def project do
    [app: :blockchain,
     version: "0.1.2",
      elixir: "~> 1.4",
      description: "Ethereum's Blockchain Manager",
      package: [
        maintainers: ["Geoffrey Hayes", "Ayrat Badykov", "Mason Forest"],
        licenses: ["MIT"],
        links: %{"GitHub" => "https://github.com/exthereum/blockchain"}
      ],
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger],
     mod: {Blockchain.Application, []}]
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
      {:libsecp256k1, "~> 0.1.2"},
      {:keccakf1600, "~> 2.0.0", hex: :keccakf1600_orig},
      {:credo, "~> 0.8", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.14", only: :dev, runtime: false},
      {:merkle_patricia_tree, "~> 0.2.3"},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:ex_rlp, "~> 0.2.1"},
      {:evm, "~> 0.1.4"},
    ]
  end
end
