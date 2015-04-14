defmodule ExleveldbTest do
  use ExUnit.Case

  def db_dir do
    File.mkdir("/tmp/dbtest")
    "/tmp/dbtest"
  end

  def mock_db(name) do
    File.rm_rf name
    {:ok, mockDb} = Exleveldb.open("#{db_dir}/#{name}", [{:create_if_missing, :true}])
    mockDb
  end

  test "it's possible to open a new datastore" do
    assert mock_db("dbtest1") == ""
    assert File.exists? "/tmp/dbtest/dbtest1"
  end

  test "it's possible to put a key-value pair in the datastore" do
    assert Exleveldb.put(mock_db("dbtest2"), "test1", "test1 value") == :ok
    assert Exleveldb.put(mock_db("dbtest2_1"), "test1", "test1 value") == :ok
  end

  test "it's possible to get a value from the datastore by key" do
    ref = mock_db("dbtest3")
    Exleveldb.put(ref, "test2", "test2 value")
    assert Exleveldb.get(ref, "test2", []) == {:ok, "test2 value"}
  end

  test "it's possible to delete a stored value by key" do
    ref  = mock_db("dbtest4")
    Exleveldb.put(ref, "test3", "test3 value")
    assert Exleveldb.delete(ref, "test3") == :ok
    assert Exleveldb.delete(mock_db("dbtest4_1"), "test3") == :ok
  end

  test "it's possible to check if a datastore is empty" do
    assert Exleveldb.is_empty?(mock_db("dbtest5")) == true
  end

  test "it's possible to close a currently open datastore" do
    assert Exleveldb.close(mock_db("dbtest6")) == :ok
  end

  test "it's possible to iterate over the key-value pairs in the currently open datastore" do
    File.rm_rf("/tmp/dbtest/dbtest7")
    {:ok, ref} = Exleveldb.open("/tmp/dbtest/dbtest7", [{:create_if_missing, :true}])
    Exleveldb.put(ref, "def", "456")
    Exleveldb.put(ref, "abc", "123")
    Exleveldb.put(ref, "hij", "789")
    assert [
      {"hij", "789"},
      {"def", "456"},
      {"abc", "123"}
    ] == Exleveldb.fold(ref, fn({k,v}, acc) -> [{k,v}|acc] end, [])
  end

  test "it's possible to iterate over the keys of the currently open datastore" do
    File.rm_rf("/tmp/dbtest/dbtest8")
    {:ok, ref} = Exleveldb.open("/tmp/dbtest/dbtest8", [{:create_if_missing, :true}])
    Exleveldb.put(ref, "def", "456")
    Exleveldb.put(ref, "abc", "123")
    Exleveldb.put(ref, "hij", "789")
    assert [
      "hij",
      "def",
      "abc"
    ] == Exleveldb.fold_keys(ref, fn(k, acc) -> [k|acc] end, [])
  end

  test "it's possible to perform atomic batch writes" do
    assert Exleveldb.write(mock_db("dbtest9"), [
      {:put, "a", "1"},
      {:put, "b", "2"},
      {:delete, "a"}
    ]) == :ok
  end
  test "it's attainable to destroy a database" do
		File.rm_rf("/tmp/eleveldb.destroy.test")
		{:ok, ref} = Exleveldb.open("/tmp/eleveldb.destroy.test",[{:create_if_missing,:true}])
		:ok = Exleveldb.put(ref,<<"qwe">>,<<"123">>,[])
		Exleveldb.close(ref)
		:ok = Exleveldb.destroy("/tmp/eleveldb.destroy.test",[])
		{:error,{:db_open,_}} = Exleveldb.open("/tmp/eleveldb.destroy.test",[{:error_if_exists, :true}])
  end
end

