defmodule EthCore.MixProject do
  use Mix.Project

  def project do
    [
      app: :eth_core,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      description: "Mana Ethereum client core modules",
      package: [
        maintainers: ["Geoffrey Hayes", "Ayrat Badykov", "Mason Forest", "Vasiliy Yorkin"],
        licenses: ["MIT"],
        links: %{"GitHub" => "https://github.com/poanetwork/mana/apps/eth_core"}
      ],
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [ignore_warnings: ".dialyzer.ignore-warnings"]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 0.9.1", only: [:dev, :test], runtime: false},
      {:poison, "~> 3.1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.14", only: :dev, runtime: false},
      {:merkle_patricia_tree, in_umbrella: true},
      {:exth_crypto, in_umbrella: true},
      {:ex_rlp, "~> 0.3.0"},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false}
    ]
  end
end
