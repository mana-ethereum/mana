defmodule ExWire.Mixfile do
  use Mix.Project

  def project do
    [app: :ex_wire,
     version: "0.1.1",
     elixir: "~> 1.6",
     description: "Elixir Client for Ethereum's RLPx, DevP2P and Eth Wire Protocol",
      package: [
        maintainers: ["Mason Fischer", "Geoffrey Hayes", "Ayrat Badykov"],
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
      {:credo, "~> 0.9.1", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.16", only: :dev, runtime: false},
      {:ex_rlp, "~> 0.2.1"},
      {:blockchain, "~> 0.1.7"},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:exth_crypto, "~> 0.1.4"},
      {:evm, "~> 0.1.11"}
    ]
  end
end
