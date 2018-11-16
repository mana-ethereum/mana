defmodule CLI.ConfigTest do
  use ExUnit.Case, async: true
  doctest CLI.Config

  test "if the path contains the db folder" do
    chain_id = :ropsten
    path = CLI.Config.db_name(chain_id)
    full_db_path = Path.join([System.cwd!(), "db", "mana-" <> Atom.to_string(chain_id)])
    full_path = Path.join([System.cwd!(), "db"])
    assert path == String.to_charlist(full_db_path)
    assert(File.exists?(full_path))
  end
end
