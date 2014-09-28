defmodule Exleveldb do
  def open(name, opts) do
    name
    |> :binary.bin_to_list
    |> :eleveldb.open opts
  end

  def get(db_ref, key, opts), do: :eleveldb.get(db_ref, key, opts)
  def put(db_ref, key, val, opts), do: :eleveldb.put(db_ref, key, val, opts)
  def delete(db_ref, key, opts), do: :eleveldb.delete(db_ref, key, val, opts)
  
end
