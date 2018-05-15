defmodule MerklePatriciaTree.DB.RocksDB do
  @moduledoc """
  Implementation of MerklePatriciaTree.DB which
  is backed by rocksdb.
  """

  alias MerklePatriciaTree.{Trie, DB}

  @behaviour MerklePatriciaTree.DB

  @doc """
  Performs initialization for this db.
  """
  @spec init(DB.db_name()) :: DB.db()
  def init(db_name) do
    {:ok, db_ref} = Rox.open(db_name, create_if_missing: true)

    {__MODULE__, db_ref}
  end

  @doc """
  Retrieves a key from the database.
  """
  @spec get(DB.db_ref(), Trie.key()) :: {:ok, DB.value()} | :not_found
  def get(db_ref, key),
    do: Rox.get(db_ref, key)

  @doc """
  Stores a key in the database.
  """
  @spec put!(DB.db_ref(), Trie.key(), DB.value()) :: :ok
  def put!(db_ref, key, value),
    do: Rox.put(db_ref, key, value)
end
