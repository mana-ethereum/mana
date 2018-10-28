defmodule Cli.MixProject do
  use Mix.Project

  def project do
    [
      app: :cli,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :ethereumex]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ethereumex, "~> 0.5.0"},
      {:blockchain, in_umbrella: true},
      {:merkle_patricia_tree, in_umbrella: true}
    ]
  end
end
