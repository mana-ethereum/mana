defmodule MerklePatriciaTree.Storage do
  @moduledoc """
  Defines functions for fetching and updating nodes.
  """

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

  def storage(implementation) do
    implementation.__struct__
  end
end
