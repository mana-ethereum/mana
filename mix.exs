defmodule Mana.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      apps: [
        :logger,
        :logger_file_backend,
        :blockchain,
        :cli,
        :evm,
        :ex_wire,
        :exth,
        :exth_crypto,
        :merkle_patricia_tree,
        :jsonrpc2
      ],
      elixirc_options: [warnings_as_errors: true],
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      dialyzer: [
        flags: [:underspecs, :unknown, :unmatched_returns],
        ignore_warnings: ".dialyzer.ignore-warnings",
        plt_add_apps: [:mix, :iex, :ex_unit, :ranch, :plug, :hackney, :jason, :websockex, :cowboy]
      ],
      deps: deps()
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    [
      {:ex_rlp, "~> 0.5.0"},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0-rc.4", only: [:dev, :test], runtime: false},
      {:ethereumex, "~> 0.5.1"},
      {:jason, "~> 1.1"},
      {:credo, "~> 1.0.0-rc1", only: [:dev, :test], runtime: false},
      {:distillery, "~> 2.0", runtime: false},
      {:artificery,
       github: "mana-ethereum/artificery", branch: "hayesgm/allow-extra-args", override: true},
      {:logger_file_backend, "~> 0.0.10"}
    ]
  end
end
