defmodule Exleveldb.Mixfile do
  use Mix.Project

  def project do
    [app: :exleveldb,
     version: "0.0.1",
     elixir: "~> 1.0.0",
     description: description,
     pacakge: package,
     deps: deps]
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
  # Type `mix help deps` for more examples and options
  defp deps do
    [
      {:eleveldb, git: "https://github.com/basho/eleveldb", tag: "1.4.0"}
    ]
  end

  defp description do
    """
    Exleveldb is a thin wrapper around [Basho's eleveldb](https://github.com/basho/eleveldb).

    At the moment, Exleveldb exposes functions for the following features of LevelDB:

    * Opening a new datastore.
    * Closing an open datastore.
    * Getting values by key.
    * Storing individual key-value pairs.
    * Deleting stored key-value pairs.
    * Checking if a datastore is empty.

    The idea is to eventually add support for LevelDB's batch operations as well.
    """
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README", "LICENSE", "test"],
      contributors: ["Jonas Skovsgaard Christensen"],
      licenses: ["Apache v2.0"],
      linkes: %{"Github" => "https://github.com/skovsgaard/exleveldb.git"}
    ]
  end
end
