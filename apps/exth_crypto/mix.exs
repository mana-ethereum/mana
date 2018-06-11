defmodule ExthCrypto.Mixfile do
  use Mix.Project

  def project do
    [
      app: :exth_crypto,
      version: "0.1.4",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      description: "Mana's Crypto Suite.",
      package: [
        maintainers: ["Geoffrey Hayes", "Mason Fischer"]
      ],
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:libsecp256k1, "~> 0.1.4"},
      {:keccakf1600, "~> 2.0.0", hex: :keccakf1600_orig},
      {:credo, "~> 0.8", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.14", only: :dev, runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:binary, "~> 0.0.4"}
    ]
  end
end
