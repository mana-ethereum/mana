defmodule ExleveldbTest do
  use ExUnit.Case

  def db_dir do
    File.mkdir("dbtest")
    "dbtest"
  end

  def mock_db(name) do
    File.rm_rf name
    {:ok, mockDb} = Exleveldb.open("#{db_dir}/#{name}", [{:create_if_missing, :true}])
    mockDb
  end

  test "it's possible to open a new datastore" do
    assert mock_db("dbtest1") == ""
    assert File.exists? "dbtest/dbtest1"
  end

  test "it's possible to put a key-value pair in the datastore" do
    assert Exleveldb.put(mock_db("dbtest2"), "test1", "test1 value", []) == :ok
  end

  test "it's possible to get a value from the datastore by key" do
    Exleveldb.put(mock_db("dbtest3"), "test2", "test2 value", [])
    assert Exleveldb.get(mock_db("dbtest3"), "test2", []) == {:ok, "test2 value"}
  end

  test "it's possible to delete a stored value by key" do
    Exleveldb.put(mock_db("dbtest4"), "test3", "test3 value", [])
    assert Exleveldb.delete(mock_db("dbtest4"), "test3", []) == :ok
  end

  test "it's possible to check if a datastore is empty" do
    assert Exleveldb.is_empty?(mock_db("dbtest5")) == true
  end

  test "it's possible to close a currently open datastore" do
    assert Exleveldb.close(mock_db("dbtest6")) == :ok
  end
end
