defmodule CLI.Config do
  @moduledoc """
  CLI.Config determines the configuration for a running
  Mana instance. For example, which database to use to store
  the block tree.
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
