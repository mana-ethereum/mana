defmodule HexPrefix.Mixfile do
  use Mix.Project

  def project do
    [app: :hex_prefix,
     version: "0.1.0",
     elixir: "~> 1.0",
     description: "Ethereum's Hex Prefix encoding",
     package: [
       maintainers: ["Geoffrey Hayes", "Ayrat Badykov"],
       licenses: ["MIT"],
       links: %{"GitHub" => "https://github.com/exthereum/hex_prefix"}
     ],
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger]]
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
  defp deps do
    [
      {:credo, "~> 0.8", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.14", only: :dev, runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
    ]
  end
end
