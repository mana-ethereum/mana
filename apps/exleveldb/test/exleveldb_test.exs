defmodule ExleveldbTest do
  use ExUnit.Case, async: true

  def db_dir do
    File.mkdir("/tmp/dbtest")
    "/tmp/dbtest"
  end

  def mock_db(name) do
    File.rm_rf name
    {:ok, mockDb} = Exleveldb.open("#{db_dir()}/#{name}")
    mockDb
  end

  setup context do
    test_db_name = context[:test]
      |> Atom.to_string
      |> String.replace(" ", "-")

    on_exit fn ->
      File.rm_rf test_db_name
    end

    [db: mock_db(test_db_name), test_location: "#{db_dir()}/#{test_db_name}"]
  end

  test "it's possible to open a new datastore", context do
    assert context[:db] == "" # Opaque types suck for writing wrappers.
    assert File.exists? context[:test_location]
  end

  test "it's possible to put a key-value pair in the datastore", context do
    assert Exleveldb.put(context[:db], "test1", "test1 value") == :ok
    assert Exleveldb.put(context[:db], "test1", "test1 value") == :ok
  end

  test "it's possible to get a value from the datastore by key", context do
    Exleveldb.put(context[:db], "test2", "test2 value")
    assert Exleveldb.get(context[:db], "test2", []) == {:ok, "test2 value"}
  end

  test "it's possible to delete a stored value by key", context do
    Exleveldb.put(context[:db], "test3", "test3 value")
    assert Exleveldb.delete(context[:db], "test3") == :ok
    # Repeat once because it needs to return :ok even when there is no key/value to delete.
    assert Exleveldb.delete(context[:db], "test3") == :ok
  end

  test "it's possible to check if a datastore is empty", context do
    assert Exleveldb.is_empty?(context[:db]) == true
  end

  test "it's possible to close a currently open datastore", context do
    assert Exleveldb.close(context[:db]) == :ok
  end

  test "it's possible to fold over the key-value pairs in the currently open datastore", context do
    Exleveldb.put(context[:db], "def", "456")
    Exleveldb.put(context[:db], "abc", "123")
    Exleveldb.put(context[:db], "hij", "789")
    assert [
      {"hij", "789"},
      {"def", "456"},
      {"abc", "123"}
    ] == Exleveldb.fold(context[:db], fn({k,v}, acc) -> [{k,v}|acc] end, [])
  end

  test "it's possible to fold over the keys of the currently open datastore", context do
    Exleveldb.put(context[:db], "def", "456")
    Exleveldb.put(context[:db], "abc", "123")
    Exleveldb.put(context[:db], "hij", "789")
    assert [
      "hij",
      "def",
      "abc"
    ] == Exleveldb.fold_keys(context[:db], fn(k, acc) -> [k|acc] end, [])
  end

  test "it's possible to map over the key-value pairs in the currently open datastore", context do
    Exleveldb.put(context[:db], "def", "456")
    Exleveldb.put(context[:db], "abc", "123")
    Exleveldb.put(context[:db], "hij", "789")
    assert [
      {"abc", "123"},
      {"def", "456"},
      {"hij", "789"}
    ] == Exleveldb.map(context[:db], &(&1))
  end

  test "it's possible to map over the keys of the currently open datastore", context do
    Exleveldb.put(context[:db], "def", "456")
    Exleveldb.put(context[:db], "abc", "123")
    Exleveldb.put(context[:db], "hij", "789")
    assert [
      "abc",
      "def",
      "hij"
    ] == Exleveldb.map_keys(context[:db], &(&1))
  end

  test "it's possible to stream key-value pairs from the currently open datastore", context do
    Exleveldb.put(context[:db], "def", "456")
    Exleveldb.put(context[:db], "abc", "123")
    Exleveldb.put(context[:db], "hij", "789")
    assert [
      {"abc", "123"},
      {"def", "456"},
      {"hij", "789"}
    ] == Exleveldb.stream(context[:db]) |> Enum.take(3)
  end

  test "it's possible to stream keys from the currently open datastore", context do
    Exleveldb.put(context[:db], "def", "456")
    Exleveldb.put(context[:db], "abc", "123")
    Exleveldb.put(context[:db], "hij", "789")
    assert [
      "abc",
      "def",
      "hij"
    ] == Exleveldb.stream(context[:db], :keys_only) |> Enum.take(3)
  end

  test "it's possible to perform atomic batch writes", context do
    assert Exleveldb.write(context[:db], [
      {:put, "a", "1"},
      {:put, "b", "2"},
      {:delete, "a"}
    ]) == :ok
  end

  test "it's possible to destroy a datastore", context do
    :ok = Exleveldb.put(context[:db], "qwe", "123", [])
    Exleveldb.close(context[:db])
    assert Exleveldb.destroy(context[:test_location], []) == :ok
    assert Exleveldb.open(context[:test_location], [{:error_if_exists, :true}]) != {:ok, ""}
  end

  test "it's possible to call repair from eleveldb", context do
    :ok = Exleveldb.close(context[:db])
    assert Exleveldb.repair(context[:test_location]) == :ok
    Exleveldb.destroy(context[:test_location])
  end
end
