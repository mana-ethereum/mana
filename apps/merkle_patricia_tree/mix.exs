defmodule MerklePatriciaTree.Mixfile do
  use Mix.Project

  def project do
    [app: :merkle_patricia_tree,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:credo, "~> 0.8", only: [:dev, :test], runtime: false},
      {:ex_rlp, "~> 0.1.1"},
      {:keccakf1600, "~> 2.0.0"}
    ]
  end
end
