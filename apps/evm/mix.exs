defmodule EVM.Mixfile do
  use Mix.Project

  def project do
    [app: :evm,
     version: "0.1.14",
     elixir: "~> 1.4",
     description: "Ethereum's Virtual Machine, in all its glory.",
      package: [
        maintainers: ["Geoffrey Hayes", "Ayrat Badykov", "Mason Forest"],
        licenses: ["MIT"],
        links: %{"GitHub" => "https://github.com/exthereum/evm"}
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
     mod: {EVM.Application, []}]
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
      {:credo, "~> 0.8", only: [:dev, :test], runtime: false},
      {:poison, "~> 3.1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.14", only: :dev, runtime: false},
      {:merkle_patricia_tree, "~> 0.2.5"},
      {:keccakf1600, "~> 2.0.0", hex: :keccakf1600_orig},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
    ]
  end
end
