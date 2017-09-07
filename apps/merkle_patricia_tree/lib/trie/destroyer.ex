defmodule MerklePatriciaTree.Trie.Destroyer do
  @moduledoc """
  Destroyer is responsible for removing keys from a
  merkle trie. To remove a key, we need to make a
  delta to our trie which ends up as the canonical
  form of the given tree as defined in http://gavwood.com/Paper.pdf.

  Note: this algorithm is non-obvious, and hence why we have a good
  number of functional and invariant tests. We should add more specific
  unit tests to this module.

  """
  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.Trie.Node

  @empty_branch Node.encode_node(:empty, nil)

  @doc """
  Removes a key from a given trie, if it exists.

  This may radically change the structure of the trie.
  """
  def remove_key(trie_node, key, trie) do
    trie_remove_key(trie_node, key, trie)
  end

  # To remove this leaf, simply remove it
  defp trie_remove_key({:leaf, leaf_prefix, _value}, prefix, _trie) when prefix == leaf_prefix do
    :empty
  end

  # This key doesn't exist, do nothing.
  defp trie_remove_key({:leaf, leaf_prefix, value}, prefix, _trie) do
    {:leaf, leaf_prefix, value}
  end

  # Shed shared prefix and continue removal operation
  defp trie_remove_key({:ext, ext_prefix, node_hash}, [ext_prefix | remaining_prefix], trie) do
    existing_node = Node.decode_trie(node_hash |> Trie.into(trie))
    updated_node = trie_remove_key(existing_node, remaining_prefix, trie)

    # Handle the potential cases of children
    case updated_node do
      :empty -> :empty
      {:leaf, leaf_prefix, leaf_value} -> {:leaf, ext_prefix ++ leaf_prefix, leaf_value}
      {:ext, new_ext_prefix, new_ext_node_hash} -> {:ext, ext_prefix ++ new_ext_prefix, new_ext_node_hash}
      els -> {:ext, ext_prefix, els}
    end
  end

  # Prefix doesn't match ext, do nothing.
  defp trie_remove_key({:ext, ext_prefix, node_hash}, _prefix, _trie) do
    {:ext, ext_prefix, node_hash}
  end

  # Remove from a branch when directly on value
  defp trie_remove_key({:branch, branches}, [], _trie) when length(branches) == 17 do
    {:branch, List.replace_at(branches, 16, nil)}
  end

  # Remove beneath a branch
  # TODO: Handle removing when only have one branch option left
  defp trie_remove_key({:branch, branches}, [prefix_hd|prefix_tl], trie) when length(branches) == 17 do
    updated_branches = List.update_at(branches, prefix_hd, fn branch ->
      branch_node = branch |> Trie.into(trie) |> Node.decode_trie

      remove_key(branch_node, prefix_tl, trie) |> Node.encode_node(trie)
    end)

    non_blank_branches =
      updated_branches
      |> Enum.drop(-1)
      |> Enum.with_index
      |> Enum.filter(fn {branch, _} -> branch != @empty_branch end)

    final_value = List.last(updated_branches)

    cond do
      Enum.count(non_blank_branches) == 0 ->
        # We just have a final value, this will need to percolate up
        {:leaf, [] , final_value}
      Enum.count(non_blank_branches) == 1 and final_value == nil ->
        # We just have a node we need to percolate up
        {branch_node, i} = List.first(non_blank_branches)

        # TODO: This is illegal since ext has to have at least two items
        {:ext, [i], branch_node}
      true -> {:branch, updated_branches}
    end
  end

  # Merge into empty to create a leaf
  defp trie_remove_key(:empty, _prefix, _value, _trie) do
    :empty
  end

end