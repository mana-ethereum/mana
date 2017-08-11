defmodule ExWire.Mixfile do
  use Mix.Project

  def project do
    [app: :ex_wire,
     version: "0.1.0",
     elixir: "~> 1.4",
     description: "Elixir Client for RLPx Protocol",
      package: [
        maintainers: ["Mason Forest", "Geoffrey Hayes", "Ayrat Badykov"],
        licenses: ["MIT"],
        links: %{"GitHub" => "https://github.com/exthereum/ex_wire"}
      ],
      elixirc_paths: elixirc_paths(Mix.env),
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps()]
  end

  def application do
    [mod: {ExWire, []},
      extra_applications: [:logger]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  defp deps do
    [
      {:credo, "~> 0.8", only: [:dev, :test], runtime: false},
      {:keccakf1600, "~> 2.0.0"},
      {:libsecp256k1, "~> 0.1.2"},
      {:ex_rlp, "~> 0.2.1"},
      {:blockchain, "~> 0.1.1"},
      {:evm, "~> 0.1.3"},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
    ]
  end
end
