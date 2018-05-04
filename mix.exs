defmodule Exthereum.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      apps: [
        :abi,
        :blockchain,
        :evm,
        :ex_rlp,
        :ex_wire,
        :exth_crypto,
        :hex_prefix,
        :merkle_patricia_tree,
      ],
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    []
  end
end
