defmodule ExthTest do
  use ExUnit.Case
  doctest Exth

  test "inspect/2" do
    assert Exth.inspect([1, 2, 3], "list") == [1, 2, 3]
  end

  test "trace/1" do
    assert Exth.trace(fn -> "test" end) == :ok
  end
end
