defmodule MerklePatriciaTree.DB do
  @moduledoc """
  Defines a general key-value storage to back and persist
  out Merkle Patricia Trie. This is generally LevelDB or RocksDB in the
  community, but for testing, we'll generally use `:ets`.

  We define a callback that can be implemented by a number
  of potential backends.
  """
  defmodule KeyNotFoundError do
    defexception [:message]
  end

  @type t :: module()
  @type db_name :: any()
  @type db_ref :: any()
  @type db :: {t, db_ref}
  @type value :: binary()

  @callback init(db_name) :: db
  @callback get(db_ref, MerklePatriciaTree.Trie.key()) :: {:ok, value} | :not_found
  @callback put!(db_ref, MerklePatriciaTree.Trie.key(), value) :: :ok

  @doc """
  Retrieves a key from the database.

  ## Examples

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> MerklePatriciaTree.DB.get(db, "name")
      :not_found

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> MerklePatriciaTree.DB.put!(db, "name", "bob")
      iex> MerklePatriciaTree.DB.get(db, "name")
      {:ok, "bob"}
  """
  @spec get(db, MerklePatriciaTree.Trie.key()) :: {:ok, value} | :not_found
  def get(_db = {db_mod, db_ref}, key) do
    db_mod.get(db_ref, key)
  end

  @doc """
  Retrieves a key from the database, but raises if that key does not exist.

  ## Examples

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> MerklePatriciaTree.DB.get!(db, "name")
      ** (MerklePatriciaTree.DB.KeyNotFoundError) cannot find key `name`

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> MerklePatriciaTree.DB.put!(db, "name", "bob")
      iex> MerklePatriciaTree.DB.get!(db, "name")
      "bob"
  """
  @spec get!(db, MerklePatriciaTree.Trie.key()) :: value
  def get!(db, key) do
    case get(db, key) do
      {:ok, value} -> value
      :not_found -> raise KeyNotFoundError, message: "cannot find key `#{key}`"
    end
  end

  @doc """
  Stores a key in the database.

  ## Examples

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> MerklePatriciaTree.DB.put!(db, "name", "bob")
      iex> MerklePatriciaTree.DB.get(db, "name")
      {:ok, "bob"}
      iex> MerklePatriciaTree.DB.put!(db, "name", "tom")
      iex> MerklePatriciaTree.DB.get(db, "name")
      {:ok, "tom"}
  """
  @spec put!(db, MerklePatriciaTree.Trie.key(), value) :: :ok
  def put!(_db = {db_mod, db_ref}, key, value) do
    db_mod.put!(db_ref, key, value)
  end

  @doc """
  Removes all objects with key from the database.

  ## Examples

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> MerklePatriciaTree.DB.put!(db, "foo", "bar")
      iex> MerklePatriciaTree.DB.delete!(db, "foo")
      iex> MerklePatriciaTree.DB.get(db, "foo")
      :not_found

  """
  @spec delete!(DB.db_ref(), Trie.key()) :: :ok
  def delete!(_db = {db_mod, db_ref}, key) do
    db_mod.delete!(db_ref, key)
  end
end
