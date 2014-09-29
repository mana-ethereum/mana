defmodule Exleveldb do
  @moduledoc """
  Exleveldb is a thin wrapper around [Basho's eleveldb](https://github.com/basho/eleveldb).
  
  At the moment, Exleveldb exposes the functions defined in this module. The idea is to eventually add support for LevelDB's batch operations as well.
  """

  def open(name, opts) do
    name
    |> :binary.bin_to_list
    |> :eleveldb.open opts
  end

  def close(db_ref), do: :eleveldb.close(db_ref)

  def get(db_ref, key, opts), do: :eleveldb.get(db_ref, key, opts)
  def put(db_ref, key, val, opts), do: :eleveldb.put(db_ref, key, val, opts)
  def delete(db_ref, key, opts), do: :eleveldb.delete(db_ref, key, opts)

  def is_empty?(db_ref) do
    if is_atom(:eleveldb.is_empty(db_ref)) do
      true
    else
      false
    end
  end
end
