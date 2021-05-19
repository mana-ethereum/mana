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

  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger, :logger_file_backend]]
  end

  defp deps do
    [
      # External deps
      {:logger_file_backend, "~> 0.0.10"},
      {:libsecp256k1, "~> 0.1.10"},
      {:keccakf1600, git: "https://github.com/compound-finance/erlang-keccakf1600", branch: "jflatow/no-erl-interface"},
      {:binary, "~> 0.0.4"}
    ]
  end
end
