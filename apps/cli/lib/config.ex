defmodule CLI.Config do
  @moduledoc """
  CLI.Config determines configuration in how to run Mana
  from the CLI. For instance, which database to use.
  """

  @doc """
  The name of the database (e.g. for RocksDB) to store loaded blocks in.

  ## Examples

      iex> CLI.Config.db_name(:ropsten)
      "db/mana-ropsten"
  """
  @spec db_name(atom()) :: String.t()
  def db_name(chain_id) do
    "db/mana-" <> Atom.to_string(chain_id)
  end
end
