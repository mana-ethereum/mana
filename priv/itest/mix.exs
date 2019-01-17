defmodule Itest.MixProject do
  use Mix.Project

  def project do
    [
      app: :itest,
      version: "0.1.0",
      elixirc_options: [warnings_as_errors: true],
      elixir: "~> 1.8",
      escript: escript(),
      elixirc_paths: ["release.ex", "websocket_test.ex", "starter.ex"],
      deps: deps()
    ]
  end

  def escript() do
    [main_module: Release]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    []
  end
end
