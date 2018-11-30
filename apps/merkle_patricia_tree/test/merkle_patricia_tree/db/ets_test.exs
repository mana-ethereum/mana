defmodule MerklePatriciaTree.DB.ETSTest do
  use ExUnit.Case, async: false
  alias MerklePatriciaTree.DB
  alias MerklePatriciaTree.DB.ETS

  describe "init/1" do
    test "init creates an ets table" do
      {_, db_ref} = ETS.init(MerklePatriciaTree.Test.random_atom(20))

      ETS.put!(db_ref, "key", "value")

      assert ETS.get(db_ref, "key") == {:ok, "value"}
    end
  end

  describe "get/1" do
    test "gets value from db" do
      {_, db_ref} = ETS.init(MerklePatriciaTree.Test.random_atom(20))

      ETS.put!(db_ref, "key", "value")

      assert ETS.get(db_ref, "key") == {:ok, "value"}
      assert ETS.get(db_ref, "key2") == :not_found
    end
  end

  describe "get!/1" do
    test "fails to get value from db" do
      db = {_, db_ref} = ETS.init(MerklePatriciaTree.Test.random_atom(20))

      ETS.put!(db_ref, "key", "value")
      assert DB.get!(db, "key") == "value"

      assert_raise MerklePatriciaTree.DB.KeyNotFoundError, "cannot find key `key2`", fn ->
        DB.get!(db, "key2")
      end
    end
  end

  describe "put!/3" do
    test "puts value to db" do
      {_, db_ref} = ETS.init(MerklePatriciaTree.Test.random_atom(20))

      assert ETS.put!(db_ref, "key", "value") == :ok
      assert ETS.get(db_ref, "key") == {:ok, "value"}
    end
  end

  describe "batch_put!/2" do
    test "puts key value pairs to db" do
      {_, db_ref} = ETS.init(MerklePatriciaTree.Test.random_atom(20))

      pairs = [
        {"elixir", "erlang"},
        {"rust", "c++"},
        {"ruby", "crystal"}
      ]

      Enum.each(pairs, fn {key, _value} ->
        assert ETS.get(db_ref, key) == :not_found
      end)

      assert ETS.batch_put!(db_ref, pairs, 2) == :ok

      Enum.each(pairs, fn {key, value} ->
        assert ETS.get(db_ref, key) == {:ok, value}
      end)
    end
  end
end
