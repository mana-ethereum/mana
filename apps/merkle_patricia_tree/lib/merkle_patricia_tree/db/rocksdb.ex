defmodule MerklePatriciaTree.DB.RocksDB do
  @moduledoc """
  Implementation of MerklePatriciaTree.DB which
  is backed by rocksdb.
  """

  @behaviour MerklePatriciaTree.DB

  @doc """
  Performs initialization for this db.
  """
  @impl true
  def init(db_name) do
    {:ok, db_ref} = :rocksdb.open(db_name, create_if_missing: true)

    {__MODULE__, db_ref}
  end

  @doc """
  Retrieves a key from the database.
  """
  @impl true
  def get(_db_ref, nil), do: :not_found

  def get(db_ref, key), do: :rocksdb.get(db_ref, key, [])

  @doc """
  Stores a key in the database.
  """
  @impl true
  def put!(db_ref, key, value) do
    :rocksdb.put(db_ref, key, value, [])
  end

  @doc """
  Removes all objects with key from the database.
  """
  @impl true
  def delete!(db_ref, key) do
    case :rocksdb.delete(db_ref, key, []) do
      :ok -> :ok
    end
  end

  @doc """
  Stores key-value pairs in the database.
  """
  @impl true
  def batch_put!(db_ref, key_value_pairs, batch_size) do
    key_value_pairs
    |> Stream.chunk_every(batch_size)
    |> Stream.each(fn pairs ->
      {:ok, batch} = :rocksdb.batch()

      Enum.each(pairs, fn {key, value} ->
        :ok = :rocksdb.batch_put(batch, key, value)
      end)

      :ok = :rocksdb.write_batch(db_ref, batch, [])
    end)
    |> Stream.run()

    :ok
  end
end
