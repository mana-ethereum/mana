defmodule ExRLP.Mixfile do
  use Mix.Project

  def project do
    [
      app: :ex_rlp,
      version: "0.2.1",
      elixir: "~> 1.6",
      description: "Ethereum's Recursive Length Prefix (RLP) encoding",
      package: [
        maintainers: ["Ayrat Badykov", "Geoffrey Hayes"],
        licenses: ["MIT"],
        links: %{"GitHub" => "https://github.com/exthereum/ex_rlp"}
      ],
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [ignore_warnings: ".dialyzer.ignore-warnings"]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:credo, "~> 0.9.1", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.16", only: :dev, runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false}
    ]
  end
end
