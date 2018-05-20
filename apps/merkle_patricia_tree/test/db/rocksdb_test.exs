defmodule MerklePatriciaTree.DB.RocksDBTest do
  use ExUnit.Case, async: false

  alias MerklePatriciaTree.DB
  alias MerklePatriciaTree.DB.RocksDB

  test "init creates a rocksdb file" do
    db_name = "/tmp/db#{MerklePatriciaTree.Test.random_string(20)}"

    RocksDB.init(db_name)
    # There is no `close` function in RocksDB API (for now),
    # This means that we can't just close and re-open the db again.
    # Also we can not open it twice at the same time (it'll be in the locked state).
    # So we just check if the db file exists. This should be enough.
    assert File.exists?(db_name)
  end

  test "get/1" do
    {_, db_ref} = RocksDB.init("/tmp/db#{MerklePatriciaTree.Test.random_string(20)}")

    Rox.put(db_ref, "key", "value")
    assert RocksDB.get(db_ref, "key") == {:ok, "value"}
    assert RocksDB.get(db_ref, "key2") == :not_found
  end

  test "get!/1" do
    db = {_, db_ref} = RocksDB.init("/tmp/db#{MerklePatriciaTree.Test.random_string(20)}")

    Rox.put(db_ref, "key", "value")
    assert DB.get!(db, "key") == "value"

    assert_raise MerklePatriciaTree.DB.KeyNotFoundError, "cannot find key `key2`", fn ->
      DB.get!(db, "key2")
    end
  end

  test "put!/2" do
    {_, db_ref} = RocksDB.init("/tmp/db#{MerklePatriciaTree.Test.random_string(20)}")

    assert RocksDB.put!(db_ref, "key", "value") == :ok
    assert Rox.get(db_ref, "key") == {:ok, "value"}
  end

  test "simple init, put, get" do
    db = {_, db_ref} = RocksDB.init("/tmp/db#{MerklePatriciaTree.Test.random_string(20)}")

    assert RocksDB.put!(db_ref, "name", "bob") == :ok
    assert DB.get!(db, "name") == "bob"
    assert RocksDB.get(db_ref, "age") == :not_found
  end
end
