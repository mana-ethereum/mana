defmodule JSONRPC2.Mixfile do
  use Mix.Project

  @version "0.0.1"

  def project do
    [
      app: :jsonrpc2,
      version: @version,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      description: description(),
      name: "JSONRPC2",
      elixirc_paths: elixirc_paths(Mix.env()),
      # elixirc_options: [warnings_as_errors: true],
      elixir: "~> 1.7.4",
      start_permanent: Mix.env() == :prod,
      dialyzer: [
        flags: [:underspecs, :unknown, :unmatched_returns],
        plt_add_apps: [:mix, :iex, :ex_unit, :ranch, :plug, :hackney, :jason, :websockex, :cowboy]
      ]
    ]
  end

  def application do
    [applications: [:logger, :cowboy, :ranch, :plug, :plug_cowboy], mod: {JSONRPC2, []}]
  end

  defp deps do
    [
      # in app
      {:ex_wire, in_umbrella: true},
      {:exth_crypto, in_umbrella: true},
      {:cowboy, "~> 2.5"},
      {:jason, "~> 1.1"},
      {:ranch, "~> 1.6"},
      {:plug, "~> 1.7"},
      {:plug_cowboy, "~> 2.0"},
      # testing and other stuff
      {:credo, "~> 1.0.0-rc1", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.4", only: [:dev, :test], runtime: false},
      {:hackney, "~> 1.6", only: [:test]},
      {:websockex,
       git: "https://github.com/mana-ethereum/websockex.git", branch: "master", only: [:test]},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp description do
    "JSON-RPC 2.0 for Elixir. https://github.com/fanduel/jsonrpc2-elixir"
  end
end
