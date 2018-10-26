defmodule MerklePatriciaTree.StorageBehaviour do
  @moduledoc """
  Defines functions for fetching and updating nodes.
  """

  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.Trie.Node

  @type t :: struct()

  @callback fetch_node(t) :: Node.trie_node()

  @callback put_node(node, t) :: nil | binary()

  @callback remove_key(t, Trie.key()) :: t

  @callback update_key(t(), Trie.key(), ExRLP.t() | nil) :: t

  @callback get_key(t(), Trie.key()) :: t()

  @callback into(binary(), t) :: t

  @callback store(t) :: t

  def storage(implementation) do
    implementation.__struct__
  end
end
