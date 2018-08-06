defmodule ABI.Mixfile do
  use Mix.Project

  def project do
    [app: :abi,
     version: "0.1.12",
     build_path: "../../_build",
     config_path: "../../config/config.exs",
     deps_path: "../../deps",
     lockfile: "../../mix.lock",
      description: "Ethereum's ABI Interface",
      package: [
        maintainers: ["Mason Fischer"],
        licenses: ["MIT"],
        links: %{"GitHub" => "https://github.com/poanetwork/mana/tree/master/apps/abi"}
      ],
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps()]
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
      {:ex_doc, "~> 0.14", only: :dev, runtime: false},
      {:poison, "~> 3.1", only: [:dev, :test]},
      {:exth_crypto, in_umbrella: true}
    ]
  end
end
