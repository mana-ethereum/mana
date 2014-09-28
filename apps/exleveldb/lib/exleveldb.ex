defmodule Exleveldb do
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
