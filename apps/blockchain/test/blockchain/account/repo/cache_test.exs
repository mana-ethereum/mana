defmodule Blockchain.Account.Repo.CacheTest do
  use ExUnit.Case, async: true

  alias Blockchain.Account
  alias Blockchain.Account.Repo.Cache

  describe "update_current_value/4" do
    test "sets current_value" do
      cache = %Cache{}

      address = <<1>>
      key = 2
      value = 5

      result = Cache.update_current_value(cache, address, key, value)
      expected_result = %{<<1>> => %{2 => %{current_value: 5}}}

      assert result.storage_cache == expected_result
    end

    test "updates current_value" do
      cache = %Cache{storage_cache: %{<<1>> => %{2 => %{current_value: 5}}}}

      address = <<1>>
      key = 2
      value = 6

      result = Cache.update_current_value(cache, address, key, value)
      expected_result = %{<<1>> => %{2 => %{current_value: 6}}}

      assert result.storage_cache == expected_result
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

      assert result.storage_cache == expected_result
    end

    test "updates initial_value" do
      cache = %Cache{storage_cache: %{<<1>> => %{2 => %{initial_value: 5}}}}

      address = <<1>>
      key = 2
      value = 6

      result = Cache.add_initial_value(cache, address, key, value)
      expected_result = %{<<1>> => %{2 => %{initial_value: 6}}}

      assert result.storage_cache == expected_result
    end
  end

  describe "current_value/3" do
    test "gets current_value when key cache exists" do
      cache = %Cache{storage_cache: %{<<1>> => %{2 => %{current_value: 5}}}}

      address = <<1>>
      key = 2

      result = Cache.current_value(cache, address, key)

      assert result == 5
    end

    test "gets current_value when key cache does not exist" do
      cache = %Cache{storage_cache: %{<<1>> => %{9 => %{current_value: 5}}}}

      address = <<1>>
      key = 2

      result = Cache.current_value(cache, address, key)

      assert is_nil(result)
    end
  end

  describe "initial_current/3" do
    test "gets initial_value when key cache exists" do
      cache = %Cache{storage_cache: %{<<1>> => %{2 => %{initial_value: 5}}}}

      address = <<1>>
      key = 2

      result = Cache.initial_value(cache, address, key)

      assert result == 5
    end

    test "gets initial_value when key cache does not exist" do
      cache = %Cache{storage_cache: %{<<1>> => %{9 => %{initial_value: 5}}}}

      address = <<1>>
      key = 2

      result = Cache.initial_value(cache, address, key)

      assert is_nil(result)
    end
  end

  describe "remove_current_value/3" do
    test "deleted current value" do
      cache = %Cache{storage_cache: %{<<1>> => %{2 => %{initial_value: 5}}}}

      address = <<1>>
      key = 2

      result =
        cache
        |> Cache.remove_current_value(address, key)
        |> Cache.current_value(address, key)

      assert result == :deleted
    end
  end

  describe "reset_account_storage_cache/2" do
    test "resets account's storage cache" do
      address = <<1>>
      key = 9
      cache = %Cache{storage_cache: %{address => %{key => %{current_value: 5}}}}

      refute is_nil(Cache.current_value(cache, address, key))

      updated_cache = Cache.reset_account_storage_cache(cache, address)

      assert is_nil(Cache.current_value(updated_cache, address, key))
    end
  end

  describe "update_account/3" do
    test "adds new account to the cache" do
      account = %Account{
        nonce: 5,
        balance: 10,
        storage_root: <<0x00, 0x01>>,
        code_hash: <<0x01, 0x02>>
      }

      address = <<1>>

      cache = %Cache{}

      updated_cache = Cache.update_account(cache, address, account)

      assert updated_cache.accounts_cache == %{address => account}
    end

    test "updates the account in the cache" do
      account = %Account{
        nonce: 5,
        balance: 10,
        storage_root: <<0x00, 0x01>>,
        code_hash: <<0x01, 0x02>>
      }

      address = <<1>>
      code = <<5>>

      cache = %Cache{accounts_cache: %{address => account}}

      updated_cache = Cache.update_account(cache, address, {account, code})

      assert updated_cache.accounts_cache == %{address => {account, code}}
    end
  end

  describe "commit_storage/2" do
    test "saves value to state" do
      ets_db = MerklePatriciaTree.Test.random_ets_db()
      state = MerklePatriciaTree.Trie.new(ets_db)
      address = <<1>>
      key = 2
      value = 5

      # we need to create a blank account
      state_with_account = Account.reset_account(state, address)

      cache = %Cache{storage_cache: %{address => %{key => %{current_value: value}}}}

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

      cache = %Cache{storage_cache: %{address => %{key => %{current_value: :deleted}}}}

      updated_state = Cache.commit(cache, state_with_account)

      result = Account.get_storage(updated_state, address, key)

      assert result == :key_not_found
    end
  end

  describe "commit accounts" do
    test "updates account with code" do
      ets_db = MerklePatriciaTree.Test.random_ets_db()
      state = MerklePatriciaTree.Trie.new(ets_db)
      address = <<1>>

      # we need to create a blank account with storage
      state_with_account = Account.reset_account(state, address)

      new_account = %Account{
        nonce: 5,
        balance: 10,
        storage_root: <<0x00, 0x01>>,
        code_hash: <<0x01, 0x02>>
      }

      code = <<2, 99>>

      cache = %Cache{accounts_cache: %{address => {:dirty, new_account, {:dirty, code}}}}

      committed_state = Cache.commit(cache, state_with_account)

      found_account = Account.get_account(committed_state, address)
      assert %{found_account | code_hash: new_account.code_hash} == new_account

      {:ok, found_code} = Account.machine_code(committed_state, address)
      assert found_code == code
    end

    test "does not update account if account in cache is clean" do
      ets_db = MerklePatriciaTree.Test.random_ets_db()
      state = MerklePatriciaTree.Trie.new(ets_db)
      address = <<1>>

      # we need to create a blank account with storage
      state_with_account = Account.reset_account(state, address)

      new_account = %Account{
        nonce: 5,
        balance: 10,
        storage_root: <<0x00, 0x01>>,
        code_hash: <<0x01, 0x02>>
      }

      code = <<2, 99>>

      cache = %Cache{accounts_cache: %{address => {:clean, new_account, code}}}

      committed_state = Cache.commit(cache, state_with_account)

      found_account = Account.get_account(committed_state, address)
      assert found_account == %Account{}

      {:ok, found_code} = Account.machine_code(committed_state, address)
      assert found_code == ""
    end

    test "updates code if it's dirty" do
      ets_db = MerklePatriciaTree.Test.random_ets_db()
      state = MerklePatriciaTree.Trie.new(ets_db)
      address = <<1>>

      # we need to create a blank account with storage
      state_with_account = Account.reset_account(state, address)

      {:ok, found_code} = Account.machine_code(state_with_account, address)
      assert found_code == ""

      new_account = %Account{
        nonce: 5,
        balance: 10,
        storage_root: <<0x00, 0x01>>,
        code_hash: <<0x01, 0x02>>
      }

      code = <<2, 99>>

      cache = %Cache{accounts_cache: %{address => {:dirty, new_account, {:dirty, code}}}}

      committed_state = Cache.commit(cache, state_with_account)

      {:ok, found_code} = Account.machine_code(committed_state, address)
      assert found_code == code
    end

    test "does not update code if it's clean" do
      ets_db = MerklePatriciaTree.Test.random_ets_db()
      state = MerklePatriciaTree.Trie.new(ets_db)
      address = <<1>>

      # we need to create a blank account with storage
      state_with_account = Account.reset_account(state, address)

      {:ok, found_code} = Account.machine_code(state_with_account, address)
      assert found_code == ""

      new_account = %Account{
        nonce: 5,
        balance: 10,
        storage_root: <<0x00, 0x01>>,
        code_hash: <<0x01, 0x02>>
      }

      code = <<5, 9>>

      cache = %Cache{accounts_cache: %{address => {:dirty, new_account, {:clean, code}}}}

      committed_state = Cache.commit(cache, state_with_account)

      result = Account.machine_code(committed_state, address)
      assert result == :not_found
    end

    test "creates new account from cache" do
      ets_db = MerklePatriciaTree.Test.random_ets_db()
      state = MerklePatriciaTree.Trie.new(ets_db)
      address = <<1>>

      new_account = %Account{
        nonce: 5,
        balance: 10,
        storage_root: <<0x00, 0x01>>,
        code_hash: <<0x01, 0x02>>
      }

      cache = %Cache{accounts_cache: %{address => {:dirty, new_account, nil}}}

      committed_state = Cache.commit(cache, state)

      found_account = Account.get_account(committed_state, address)
      assert %{found_account | code_hash: new_account.code_hash} == new_account
    end
  end
end
