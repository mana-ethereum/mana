defmodule Exleveldb do
  @moduledoc """
  Exleveldb is a thin wrapper around [Basho's eleveldb](https://github.com/basho/eleveldb).
  
  At the moment, Exleveldb exposes the functions defined in this module. The idea is to eventually add support for iterators and LevelDB's batch operations as well.
  """

  @doc """
  Opens a new datastore in the directory called `name`. If `name` does not exist already, `opts` needs to include `[{:create_if_missing, :true}]` to work properly.
  
  Returns `{:ok, ""}` where the empty string is a reference to the opened datastore or, on error, `{:error, {:type, 'reason for error'}}`.
  """
  def open(name, opts) do
    name
    |> :binary.bin_to_list
    |> :eleveldb.open opts
  end

  @doc """
  Takes a reference as returned by `open/2` and closes the specified datastore if open.

  Returns `:ok` or `{:error, {:type, 'reason for error'}}` on error.
  """
  def close(db_ref), do: :eleveldb.close(db_ref)

  @doc """
  Retrieves a value in LevelDB by key. Takes a reference as returned by `open/2`, a key, and an options list.

  Returns `{:ok, value}` when successful or `:not_found` on failed lookup.
  """
  def get(db_ref, key, opts), do: :eleveldb.get(db_ref, key, opts)
 
  @doc """
  Puts a single key-value pair into the datastore specified by the reference, `db_ref`.

  Returns `:ok` if successful or `{:error, reference {:type, action}}` on error.
  """
  def put(db_ref, key, val, opts), do: :eleveldb.put(db_ref, key, val, opts)

  @doc """
  Deletes the value associated with `key` in the datastore, `db_ref`.

  Returns `:ok` when successful or `{:error, reference, {:type, action}}` on error.
  """
  def delete(db_ref, key, opts), do: :eleveldb.delete(db_ref, key, opts)

  @doc """
  Checks whether the datastore specified by `db_ref` is empty and returns an Elixir boolean.
  """
  def is_empty?(db_ref) do
    if is_atom(:eleveldb.is_empty(db_ref)) do
      true
    else
      false
    end
  end
end
