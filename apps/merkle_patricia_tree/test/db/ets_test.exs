defmodule MerklePatriciaTree.DB.ETSTest do
  use ExUnit.Case, async: false
  alias MerklePatriciaTree.DB
  alias MerklePatriciaTree.DB.ETS

  test "init creates an ets table" do
    {_, db_ref} = ETS.init(MerklePatriciaTree.Test.random_atom(20))

    :ets.insert(db_ref, {"key", "value"})
    assert :ets.lookup(db_ref, "key") == [{"key", "value"}]
  end

  test "get/1" do
    {_, db_ref} = ETS.init(MerklePatriciaTree.Test.random_atom(20))

    :ets.insert(db_ref, {"key", "value"})
    assert ETS.get(db_ref, "key") == {:ok, "value"}
    assert ETS.get(db_ref, "key2") == :not_found
  end

  test "get!/1" do
    db = {_, db_ref} = ETS.init(MerklePatriciaTree.Test.random_atom(20))

    :ets.insert(db_ref, {"key", "value"})
    assert DB.get!(db, "key") == "value"

    assert_raise MerklePatriciaTree.DB.KeyNotFoundError, "cannot find key `key2`", fn ->
      DB.get!(db, "key2")
    end
  end

  test "put!/2" do
    {_, db_ref} = ETS.init(MerklePatriciaTree.Test.random_atom(20))

    assert ETS.put!(db_ref, "key", "value") == :ok
    assert :ets.lookup(db_ref, "key") == [{"key", "value"}]
  end
end
