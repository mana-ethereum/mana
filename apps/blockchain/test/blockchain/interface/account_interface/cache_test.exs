defmodule Blockchain.Interface.AccountInterface.CacheTest do
  use ExUnit.Case, async: true

  alias Blockchain.Interface.AccountInterface.Cache

  alias Blockchain.Interface.AccountInterface.Cache

  describe "update_current_value/4" do
    test "sets current_value" do
      cache = %Cache{cache: %{}}

      address = <<1>>
      key = 2
      value = 5

      result = Cache.update_current_value(cache, address, key, value)
      expected_result = %{<<1>> => %{2 => %{current_value: 5}}}

      assert result.cache == expected_result
    end

    test "updates current_value" do
      cache = %Cache{cache: %{<<1>> => %{2 => %{current_value: 5}}}}

      address = <<1>>
      key = 2
      value = 6

      result = Cache.update_current_value(cache, address, key, value)
      expected_result = %{<<1>> => %{2 => %{current_value: 6}}}

      assert result.cache == expected_result
    end
  end

  describe "add_initial_value/4" do
    test "sets initial_value" do
      cache = %Cache{cache: %{}}

      address = <<1>>
      key = 2
      value = 5

      result = Cache.add_initial_value(cache, address, key, value)
      expected_result = %{<<1>> => %{2 => %{initial_value: 5}}}

      assert result.cache == expected_result
    end

    test "updates initial_value" do
      cache = %Cache{cache: %{<<1>> => %{2 => %{initial_value: 5}}}}

      address = <<1>>
      key = 2
      value = 6

      result = Cache.add_initial_value(cache, address, key, value)
      expected_result = %{<<1>> => %{2 => %{initial_value: 6}}}

      assert result.cache == expected_result
    end
  end

  describe "get_current_value/3" do
    test "gets current_value when key cache exists" do
      cache = %Cache{cache: %{<<1>> => %{2 => %{current_value: 5}}}}

      address = <<1>>
      key = 2

      result = Cache.get_current_value(cache, address, key)

      assert result == 5
    end

    test "gets current_value when key cache does not exist" do
      cache = %Cache{cache: %{<<1>> => %{9 => %{current_value: 5}}}}

      address = <<1>>
      key = 2

      result = Cache.get_current_value(cache, address, key)

      assert is_nil(result)
    end
  end

  describe "get_initial_current/3" do
    test "gets initial_value when key cache exists" do
      cache = %Cache{cache: %{<<1>> => %{2 => %{initial_value: 5}}}}

      address = <<1>>
      key = 2

      result = Cache.get_initial_value(cache, address, key)

      assert result == 5
    end

    test "gets initial_value when key cache does not exist" do
      cache = %Cache{cache: %{<<1>> => %{9 => %{initial_value: 5}}}}

      address = <<1>>
      key = 2

      result = Cache.get_initial_value(cache, address, key)

      assert is_nil(result)
    end
  end

  describe "remove_current_value/3" do
    test "deleted current value" do
      cache = %Cache{cache: %{<<1>> => %{2 => %{initial_value: 5}}}}

      address = <<1>>
      key = 2

      result =
        cache
        |> Cache.remove_current_value(address, key)
        |> Cache.get_current_value(address, key)

      assert result == :deleted
    end
  end
end
