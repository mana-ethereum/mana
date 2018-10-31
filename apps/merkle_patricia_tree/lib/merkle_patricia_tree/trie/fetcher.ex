defmodule MerklePatriciaTree.Trie.Fetcher do
  alias MerklePatriciaTree.ListHelper
  alias MerklePatriciaTree.TrieStorage
  alias MerklePatriciaTree.Trie.Helper

  def get(trie, key) do
    do_get(trie, Helper.get_nibbles(key))
  end

  @spec do_get(TrieStorage.t() | nil, [integer()]) :: binary() | nil
  defp do_get(nil, _), do: nil

  defp do_get(trie, nibbles = [nibble | rest]) do
    # Let's decode `c(I, i)`

    case TrieStorage.fetch_node(trie) do
      # No node, bail
      :empty ->
        nil

      # Leaf node
      {:leaf, prefix, value} ->
        if prefix == nibbles,
          do: value,
          else: nil

      # Extension, continue walking trie if we match
      {:ext, shared_prefix, next_node} ->
        case ListHelper.get_postfix(nibbles, shared_prefix) do
          # Did not match extension node
          nil ->
            nil

          rest ->
            next_node |> TrieStorage.into(trie) |> do_get(rest)
        end

      # Branch node
      {:branch, branches} ->
        case Enum.at(branches, nibble) do
          [] -> nil
          node_hash -> node_hash |> TrieStorage.into(trie) |> do_get(rest)
        end
    end
  end

  defp do_get(trie, []) do
    # No prefix left, its either branch or leaf node
    case TrieStorage.fetch_node(trie) do
      # In branch node value is always the last element
      {:branch, branches} ->
        value = List.last(branches)
        # Decode empty value as nil, see Eq.(194)
        if value == <<>>, do: nil, else: value

      {:leaf, [], v} ->
        v

      _ ->
        nil
    end
  end
end
