defmodule Blockchain.Interface.AccountInterface.CacheTest do
  use ExUnit.Case, async: true

  alias Blockchain.Interface.AccountInterface.Cache
  alias Blockchain.Account

  describe "update_current_value/4" do
    test "sets current_value" do
      cache = %Cache{}

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
      cache = %Cache{}

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

  describe "current_value/3" do
    test "gets current_value when key cache exists" do
      cache = %Cache{cache: %{<<1>> => %{2 => %{current_value: 5}}}}

      address = <<1>>
      key = 2

      result = Cache.current_value(cache, address, key)

      assert result == 5
    end

    test "gets current_value when key cache does not exist" do
      cache = %Cache{cache: %{<<1>> => %{9 => %{current_value: 5}}}}

      address = <<1>>
      key = 2

      result = Cache.current_value(cache, address, key)

      assert is_nil(result)
    end
  end

  describe "initial_current/3" do
    test "gets initial_value when key cache exists" do
      cache = %Cache{cache: %{<<1>> => %{2 => %{initial_value: 5}}}}

      address = <<1>>
      key = 2

      result = Cache.initial_value(cache, address, key)

      assert result == 5
    end

    test "gets initial_value when key cache does not exist" do
      cache = %Cache{cache: %{<<1>> => %{9 => %{initial_value: 5}}}}

      address = <<1>>
      key = 2

      result = Cache.initial_value(cache, address, key)

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
        |> Cache.current_value(address, key)

      assert result == :deleted
    end
  end

  describe "commit/2" do
    test "saves value to state" do
      ets_db = MerklePatriciaTree.Test.random_ets_db()
      state = MerklePatriciaTree.Trie.new(ets_db)
      address = <<1>>
      key = 2
      value = 5

      # we need to create a blank account
      state_with_account = Account.reset_account(state, address)

      cache = %Cache{cache: %{address => %{key => %{current_value: value}}}}

      updated_state = Cache.commit(cache, state_with_account)

      {:ok, found_value} = Account.get_storage(updated_state, address, key)

      assert found_value == value
    end

    test "deletes key from state" do
      ets_db = MerklePatriciaTree.Test.random_ets_db()
      state = MerklePatriciaTree.Trie.new(ets_db)
      address = <<1>>
      key = 2
      value = 5

      # we need to create a blank account with storage
      state_with_account =
        state
        |> Account.reset_account(address)
        |> Account.put_storage(address, key, value)

      {:ok, ^value} = Account.get_storage(state_with_account, address, key)

      cache = %Cache{cache: %{address => %{key => %{current_value: :deleted}}}}

      updated_state = Cache.commit(cache, state_with_account)

      result = Account.get_storage(updated_state, address, key)

      assert result == :key_not_found
    end
  end
end
