defmodule ExDevp2p.Mixfile do
  use Mix.Project

  def project do
    [app: :ex_devp2p,
     version: "0.1.0",
     elixir: "~> 1.4",
     elixirc_paths: elixirc_paths(Mix.env),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [mod: {ExDevp2p, []},
      extra_applications: [:logger]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  defp deps do
    [
      {:credo, "~> 0.8", only: [:dev, :test], runtime: false},
      {:keccakf1600, git: "https://github.com/jur0/erlang-keccakf1600", branch: "original-keccak"},
      {:libsecp256k1, [github: "mbrix/libsecp256k1", manager: :rebar]},
      {:ex_rlp, path: "../ex_rlp"}
    ]
  end
end
