defmodule MerklePatriciaTree.CachingTrieTest do
  use ExUnit.Case, async: true

  alias MerklePatriciaTree.CachingTrie
  alias MerklePatriciaTree.Trie

  setup do
    disk_trie =
      "/tmp/#{MerklePatriciaTree.Test.random_string(20)}"
      |> MerklePatriciaTree.DB.RocksDB.init()
      |> MerklePatriciaTree.Trie.new()

    {:ok, %{disk_trie: disk_trie}}
  end

  describe "new/1" do
    test "initializes new CachingTrie", %{disk_trie: disk_trie} do
      caching_trie = CachingTrie.new(disk_trie)

      assert caching_trie.in_memory_trie.root_hash == disk_trie.root_hash
    end
  end

  describe "get_key/2" do
    test "fetches data from disk trie when in-memory try is empty", %{disk_trie: disk_trie} do
      disk_trie = Trie.update_key(disk_trie, "foo", "bar")

      caching_trie = CachingTrie.new(disk_trie)

      result = CachingTrie.get_key(caching_trie, "foo")
      assert result == "bar"
    end

    test "fetched one value from disk trie, another from in-memory try", %{disk_trie: disk_trie} do
      disk_trie = Trie.update_key(disk_trie, "foo", "bar")

      caching_trie =
        disk_trie
        |> CachingTrie.new()
        |> CachingTrie.update_key("foo1", "bar1")

      result = CachingTrie.get_key(caching_trie, "foo")
      assert result == "bar"

      result = Trie.get_key(caching_trie.trie, "foo")
      assert result == "bar"

      result = CachingTrie.get_key(caching_trie, "foo1")
      assert result == "bar1"

      result = Trie.get_key(caching_trie.in_memory_trie, "foo1")
      assert result == "bar1"
    end
  end

  describe "remove_key/2" do
    test "removes key updating in-memory trie", %{disk_trie: disk_trie} do
      caching_trie =
        disk_trie
        |> Trie.update_key("foo", "bar")
        |> Trie.update_key("foo1", "bar1")
        |> CachingTrie.new()

      result = CachingTrie.get_key(caching_trie, "foo")
      assert result == "bar"

      updated_caching_trie = CachingTrie.remove_key(caching_trie, "foo")

      result = CachingTrie.get_key(updated_caching_trie, "foo")
      assert is_nil(result)

      result = CachingTrie.get_key(caching_trie.trie, "foo")
      assert result == "bar"
    end
  end

  describe "update_key/3" do
    test "updates key in in-memory trie", %{disk_trie: disk_trie} do
      caching_trie = CachingTrie.new(disk_trie)

      updated_caching_trie = CachingTrie.update_key(caching_trie, "foo", "bar")

      result = CachingTrie.get_key(updated_caching_trie, "foo")
      assert result == "bar"

      result = Trie.get_key(updated_caching_trie.in_memory_trie, "foo")
      assert result == "bar"
    end

    test "sets correct storage root to in-memory trie", %{disk_trie: disk_trie} do
      disk_trie = Trie.update_key(disk_trie, "elixir", "erlang")

      updated_disk_trie =
        disk_trie
        |> Trie.update_key("foo", "bar")
        |> Trie.update_key("foo1", "bar1")
        |> Trie.update_key("foo2", "bar2")

      caching_trie =
        disk_trie
        |> CachingTrie.new()
        |> CachingTrie.update_key("foo", "bar")
        |> CachingTrie.update_key("foo1", "bar1")
        |> CachingTrie.update_key("foo2", "bar2")

      assert updated_disk_trie.root_hash == caching_trie.in_memory_trie.root_hash
      assert caching_trie.trie.root_hash == disk_trie.root_hash
    end
  end

  describe "update_subtrie_key/4" do
    test "update in-memory subtrie", %{disk_trie: disk_trie} do
      disk_trie = Trie.update_key(disk_trie, "java", "kotlin")

      caching_trie =
        disk_trie
        |> CachingTrie.new()
        |> CachingTrie.update_key("elixir", "erlang")

      {subtrie, updated_caching_trie} =
        CachingTrie.update_subtrie_key(caching_trie, Trie.empty_trie_root_hash(), "rust", "c++")

      assert CachingTrie.get_key(subtrie, "rust") == "c++"

      trie_changes = [
        {:update, disk_trie.root_hash, "elixir", "erlang"},
        {:update, Trie.empty_trie_root_hash(), "rust", "c++"}
      ]

      assert subtrie.trie_changes == trie_changes
      assert updated_caching_trie.trie_changes == trie_changes

      assert updated_caching_trie.in_memory_trie.root_hash ==
               caching_trie.in_memory_trie.root_hash
    end
  end

  describe "remove_subtrie_key/4" do
    test "removes key from in-memory subtrie", %{disk_trie: disk_trie} do
      caching_trie = CachingTrie.new(disk_trie)

      {subtrie, updated_caching_trie} =
        CachingTrie.update_subtrie_key(
          caching_trie,
          Trie.empty_trie_root_hash(),
          "elixir",
          "erlang"
        )

      {subtrie, updated_caching_trie} =
        CachingTrie.update_subtrie_key(
          updated_caching_trie,
          subtrie.in_memory_trie.root_hash,
          "rust",
          "c++"
        )

      assert CachingTrie.get_subtrie_key(
               updated_caching_trie,
               subtrie.in_memory_trie.root_hash,
               "elixir"
             ) == "erlang"

      assert CachingTrie.get_subtrie_key(
               updated_caching_trie,
               subtrie.in_memory_trie.root_hash,
               "rust"
             ) == "c++"

      {updated_subtrie, updated_caching_trie} =
        CachingTrie.remove_subtrie_key(
          updated_caching_trie,
          subtrie.in_memory_trie.root_hash,
          "rust"
        )

      assert CachingTrie.get_subtrie_key(
               updated_caching_trie,
               updated_subtrie.in_memory_trie.root_hash,
               "elixir"
             ) == "erlang"

      assert CachingTrie.get_subtrie_key(
               updated_caching_trie,
               updated_subtrie.in_memory_trie.root_hash,
               "rust"
             ) == nil
    end
  end
end
