defmodule MerklePatriciaTree.TrieStorage do
  @moduledoc """
  Defines functions for fetching and updating nodes.
  """

  alias MerklePatriciaTree.DB
  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.Trie.Node

  @type t :: struct()

  @callback fetch_node(t) :: Node.trie_node()

  @callback put_node(node, t) :: nil | binary()

  @callback remove_key(t, Trie.key()) :: t

  @callback remove_subtrie_key(t, Trie.root_hash(), Trie.key()) :: {t, t}

  @callback update_key(t(), Trie.key(), ExRLP.t() | nil) :: t

  @callback update_subtrie_key(t(), Trie.root_hash(), Trie.key(), ExRLP.t() | nil) :: {t, t}

  @callback put_raw_key!(t(), binary(), binary()) :: t()

  @callback get_raw_key(t(), binary()) :: {:ok, binary()} | :not_found

  @callback get_key(t(), Trie.key()) :: nil | binary()

  @callback get_subtrie_key(t(), Trie.root_hash(), Trie.key()) :: nil | binary()

  @callback into(binary(), t) :: t

  @callback root_hash(t()) :: Trie.root_hash()

  @callback set_root_hash(t(), Trie.root_hash()) :: t()

  @callback store(t) :: t

  @callback permanent_db(t) :: DB.db()

  @callback commit!(t) :: t

  def fetch_node(implementation) do
    storage(implementation).fetch_node(implementation)
  end

  def put_node(node, implementation) do
    storage(implementation).put_node(node, implementation)
  end

  def remove_key(implementation, key) do
    storage(implementation).remove_key(implementation, key)
  end

  def remove_subtrie_key(implementation, root_hash, key) do
    storage(implementation).remove_subtrie_key(implementation, root_hash, key)
  end

  def update_key(implementation, key, value) do
    storage(implementation).update_key(implementation, key, value)
  end

  def update_subtrie_key(implementation, root_hash, key, value) do
    storage(implementation).update_subtrie_key(implementation, root_hash, key, value)
  end

  def put_raw_key!(implementation, key, value) do
    storage(implementation).put_raw_key!(implementation, key, value)
  end

  def get_raw_key(implementation, key) do
    storage(implementation).get_raw_key(implementation, key)
  end

  def get_key(implementation, key) do
    storage(implementation).get_key(implementation, key)
  end

  def get_subtrie_key(implementation, root_hash, key) do
    storage(implementation).get_subtrie_key(implementation, root_hash, key)
  end

  def into(root_hash, implementation) do
    storage(implementation).into(root_hash, implementation)
  end

  def root_hash(implementation) do
    storage(implementation).root_hash(implementation)
  end

  def set_root_hash(implementation, root_hash) do
    storage(implementation).set_root_hash(implementation, root_hash)
  end

  def store(implementation) do
    storage(implementation).store(implementation)
  end

  def commit!(implementation) do
    storage(implementation).commit!(implementation)
  end

  def permanent_db(implementation) do
    storage(implementation).permanent_db(implementation)
  end

  defp storage(implementation) do
    implementation.__struct__
  end
end
