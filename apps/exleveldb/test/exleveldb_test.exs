defmodule ExleveldbTest do
  use ExUnit.Case

  def mock_db do
    File.rm_rf "dbtest"
    {:ok, mockDb} = Exleveldb.open("dbtest", [{:create_if_missing, :true}])
    mockDb
  end

  test "it's possible to make a new datastore" do
    assert File.exists?("dbtest/")
  end

  test "it's possible to write to the datastore" do
    assert Exleveldb.put(mock_db, "test_key", "test val", [{}])
  end

  test "it's possible to retrieve by key" do
    assert Exleveldb.get(mock_db, "test_key", [{}])
  end
end
