defmodule MerklePatriciaTree.DB.RocksDBTest do
  use ExUnit.Case, async: false

  alias MerklePatriciaTree.DB
  alias MerklePatriciaTree.DB.RocksDB

  describe "init/1" do
    test "init creates a rocksdb file" do
      db_name = String.to_charlist("/tmp/db#{MerklePatriciaTree.Test.random_string(20)}")

      RocksDB.init(db_name)
      # There is no `close` function in RocksDB API (for now),
      # This means that we can't just close and re-open the db again.
      # Also we can not open it twice at the same time (it'll be in the locked state).
      # So we just check if the db file exists. This should be enough.
      assert File.exists?(db_name)
    end
  end

  describe "get/1" do
    test "gets value from db" do
      db_name = String.to_charlist("/tmp/db#{MerklePatriciaTree.Test.random_string(20)}")
      {_, db_ref} = RocksDB.init(db_name)

      RocksDB.put!(db_ref, "key", "value")

      assert RocksDB.get(db_ref, "key") == {:ok, "value"}
      assert RocksDB.get(db_ref, "key2") == :not_found
    end
  end

  describe "get!/1" do
    test "fails to get value from db" do
      db_name = String.to_charlist("/tmp/db#{MerklePatriciaTree.Test.random_string(20)}")
      {_, db_ref} = :rocksdb.open(db_name, create_if_missing: true)

      RocksDB.put!(db_ref, "key", "value")
      assert DB.get!({RocksDB, db_ref}, "key") == "value"

      assert_raise MerklePatriciaTree.DB.KeyNotFoundError, "cannot find key `key2`", fn ->
        DB.get!({RocksDB, db_ref}, "key2")
      end
    end
  end

  describe "put/3" do
    test "puts value to db" do
      db_name = String.to_charlist("/tmp/db#{MerklePatriciaTree.Test.random_string(20)}")
      {_, db_ref} = RocksDB.init(db_name)

      assert RocksDB.put!(db_ref, "key", "value") == :ok
      assert RocksDB.get(db_ref, "key") == {:ok, "value"}
    end

    test "simple open, put, get" do
      db_name = String.to_charlist("/tmp/db#{MerklePatriciaTree.Test.random_string(20)}")
      {_, db_ref} = RocksDB.init(db_name)

      assert RocksDB.put!(db_ref, "name", "bob") == :ok
      assert DB.get!({RocksDB, db_ref}, "name") == "bob"
      assert RocksDB.get(db_ref, "age") == :not_found
    end
  end

  describe "batch_put!/2" do
    test "puts key-value pairs to db" do
      db_name = String.to_charlist("/tmp/db#{MerklePatriciaTree.Test.random_string(20)}")
      {_db, db_ref} = RocksDB.init(db_name)

      pairs = [
        {"elixir", "erlang"},
        {"rust", "c++"},
        {"ruby", "crystal"}
      ]

      Enum.each(pairs, fn {key, _value} ->
        assert RocksDB.get(db_ref, key) == :not_found
      end)

      assert RocksDB.batch_put!(db_ref, pairs) == :ok

      Enum.each(pairs, fn {key, value} ->
        assert RocksDB.get(db_ref, key) == {:ok, value}
      end)
    end
  end
end
