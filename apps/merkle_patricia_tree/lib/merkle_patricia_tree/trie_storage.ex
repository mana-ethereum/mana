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
  @callback put_batch_raw_keys!(t(), Enumerable.t(), integer()) :: t()
  @callback get_raw_key(t(), binary()) :: {:ok, binary()} | :not_found
  @callback get_key(t(), Trie.key()) :: nil | binary()
  @callback get_subtrie_key(t(), Trie.root_hash(), Trie.key()) :: nil | binary()
  @callback into(binary(), t) :: t
  @callback root_hash(t()) :: Trie.root_hash()
  @callback set_root_hash(t(), Trie.root_hash()) :: t()
  @callback store(t) :: t
  @callback permanent_db(t) :: DB.db()
  @callback commit!(t) :: t

  @default_batch_size 1000

  @spec fetch_node(t) :: Node.trie_node()
  def fetch_node(implementation) do
    storage(implementation).fetch_node(implementation)
  end

  @spec put_node(Node.trie_node(), t()) :: nil | binary()
  def put_node(node, implementation) do
    storage(implementation).put_node(node, implementation)
  end

  @spec remove_key(t(), Trie.key()) :: t()
  def remove_key(implementation, key) do
    storage(implementation).remove_key(implementation, key)
  end

  @spec remove_subtrie_key(t, Trie.root_hash(), Trie.key()) :: {t, t}
  def remove_subtrie_key(implementation, root_hash, key) do
    storage(implementation).remove_subtrie_key(implementation, root_hash, key)
  end

  @spec update_key(t(), Trie.key(), ExRLP.t() | nil) :: t
  def update_key(implementation, key, value) do
    storage(implementation).update_key(implementation, key, value)
  end

  @spec update_subtrie_key(t(), Trie.root_hash(), Trie.key(), ExRLP.t() | nil) :: {t, t}
  def update_subtrie_key(implementation, root_hash, key, value) do
    storage(implementation).update_subtrie_key(implementation, root_hash, key, value)
  end

  @spec put_raw_key!(t(), binary(), binary()) :: t()
  def put_raw_key!(implementation, key, value) do
    storage(implementation).put_raw_key!(implementation, key, value)
  end

  @spec put_batch_raw_keys!(t(), Enumerable.t(), integer()) :: t()
  def put_batch_raw_keys!(implementation, pairs, batch_size \\ @default_batch_size) do
    storage(implementation).put_batch_raw_keys!(implementation, pairs, batch_size)
  end

  @spec get_raw_key(t(), binary()) :: {:ok, binary()} | :not_found
  def get_raw_key(implementation, key) do
    storage(implementation).get_raw_key(implementation, key)
  end

  @spec get_key(t(), Trie.key()) :: nil | binary()
  def get_key(implementation, key) do
    storage(implementation).get_key(implementation, key)
  end

  @spec get_subtrie_key(t(), Trie.root_hash(), Trie.key()) :: nil | binary()
  def get_subtrie_key(implementation, root_hash, key) do
    storage(implementation).get_subtrie_key(implementation, root_hash, key)
  end

  @spec into(binary(), t) :: t
  def into(root_hash, implementation) do
    storage(implementation).into(root_hash, implementation)
  end

  @spec root_hash(t()) :: Trie.root_hash()
  def root_hash(implementation) do
    storage(implementation).root_hash(implementation)
  end

  @spec set_root_hash(t(), Trie.root_hash()) :: t()
  def set_root_hash(implementation, root_hash) do
    storage(implementation).set_root_hash(implementation, root_hash)
  end

  @spec store(t) :: t
  def store(implementation) do
    storage(implementation).store(implementation)
  end

  @spec commit!(t) :: t
  def commit!(implementation) do
    storage(implementation).commit!(implementation)
  end

  @spec permanent_db(t) :: DB.db()
  def permanent_db(implementation) do
    storage(implementation).permanent_db(implementation)
  end

  @spec storage(t) :: atom()
  defp storage(implementation) do
    implementation.__struct__
  end
end
