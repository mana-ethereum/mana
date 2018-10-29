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

  import MerklePatriciaTree.ListHelper, only: [overlap: 2]

  alias MerklePatriciaTree.StorageBehaviour
  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.Trie.Node

  @empty_branch <<>>

  @doc """
  Removes a key from a given trie, if it exists.

  This may radically change the structure of the trie.
  """
  @spec remove_key(Node.trie_node(), Trie.key(), StorageBehaviour.t()) :: Node.trie_node()
  def remove_key(trie_node, key, trie) do
    trie_remove_key(trie_node, key, trie)
  end

  # To remove this leaf, simply remove it.
  defp trie_remove_key({:leaf, leaf_prefix, _value}, prefix, _trie)
       when prefix == leaf_prefix do
    :empty
  end

  # This key doesn't exist, do nothing.
  defp trie_remove_key({:leaf, leaf_prefix, value}, _prefix, _trie) do
    {:leaf, leaf_prefix, value}
  end

  # Shed shared prefix and continue removal operation.
  defp trie_remove_key({:ext, ext_prefix, node_hash}, key_prefix, trie) do
    {_matching_prefix, ext_tl, remaining_tl} = overlap(ext_prefix, key_prefix)

    if Enum.empty?(ext_tl) do
      existing_node =
        node_hash
        |> StorageBehaviour.storage(trie).into(trie)
        |> StorageBehaviour.storage(trie).fetch_node()

      updated_node = trie_remove_key(existing_node, remaining_tl, trie)

      # Handle the potential cases of children.
      case updated_node do
        :empty ->
          :empty

        {:leaf, leaf_prefix, leaf_value} ->
          # Combine with the node below
          {:leaf, ext_prefix ++ leaf_prefix, leaf_value}

        {:ext, new_ext_prefix, new_ext_node_hash} ->
          # Combine with the node below
          {:ext, ext_prefix ++ new_ext_prefix, new_ext_node_hash}

        elements ->
          encoded = StorageBehaviour.storage(trie).put_node(elements, trie)
          {:ext, ext_prefix, encoded}
      end
    else
      # Prefix doesn't match ext, do nothing
      {:ext, ext_prefix, node_hash}
    end
  end

  # Remove from a branch when directly on value.
  defp trie_remove_key({:branch, branches}, [], _trie) when length(branches) == 17 do
    # Use <<>> as a value, otherwise it won't be RLP-serializable
    children = List.replace_at(branches, 16, <<>>)
    {:branch, children}
  end

  # Remove beneath a branch.
  defp trie_remove_key({:branch, branches}, [prefix_hd | prefix_tl], trie)
       when length(branches) == 17 do
    updated_branches =
      List.update_at(branches, prefix_hd, fn branch ->
        branch_node =
          branch
          |> StorageBehaviour.storage(trie).into(trie)
          |> StorageBehaviour.storage(trie).fetch_node()

        branch_node
        |> trie_remove_key(prefix_tl, trie)
        |> StorageBehaviour.storage(trie).put_node(trie)
      end)

    non_blank_branches =
      updated_branches
      |> Enum.drop(-1)
      |> Enum.with_index()
      |> Enum.filter(fn {branch, _} -> branch != @empty_branch end)

    final_value = List.last(updated_branches)

    cond do
      Enum.empty?(non_blank_branches) ->
        # We just have a final value, this will need to percolate up.
        {:leaf, [], final_value}

      Enum.count(non_blank_branches) == 1 and final_value == "" ->
        # We just have a node we need to percolate up.
        {branch_node, i} = List.first(non_blank_branches)

        decoded_branch_node =
          branch_node
          |> StorageBehaviour.storage(trie).into(trie)
          |> StorageBehaviour.storage(trie).fetch_node()

        case decoded_branch_node do
          {:leaf, leaf_prefix, leaf_value} ->
            {:leaf, [i | leaf_prefix], leaf_value}

          {:ext, ext_prefix, ext_node_hash} ->
            {:ext, [i | ext_prefix], ext_node_hash}

          {:branch, _branches} ->
            {:ext, [i], branch_node}
        end

      true ->
        {:branch, updated_branches}
    end
  end

  # Merge into empty to create a leaf.
  defp trie_remove_key(:empty, _prefix, _trie) do
    :empty
  end
end
