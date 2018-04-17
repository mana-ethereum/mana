defmodule MerklePatriciaTree.Trie.Builder do
  @moduledoc """
  Builder is responsible for adding keys to an
  existing merkle trie. To add a key, we need to
  make a delta to our trie that ends up as the canonical
  form of the given tree as defined in http://gavwood.com/Paper.pdf.

  Note: this algorithm is non-obvious, and hence why we have a good
  number of functional and invariant tests. We should add more specific
  unit tests to this module.

  """
  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.Trie.Node
  alias MerklePatriciaTree.ListHelper

  @empty_branch <<>>

  @doc """
  Adds a key-value pair to a given trie.

  This may radically change the structure of the trie.
  """
  @spec put_key(Node.trie_node, Trie.key, ExRLP.t, Trie.t) :: Node.trie_node
  def put_key(trie_node, key, value, trie) do
    trie_put_key(trie_node, key, value, trie)
  end

  # Merge into a leaf with identical key (overwrite)
  defp trie_put_key({:leaf, old_prefix, _value}, new_prefix, new_value, _trie) when old_prefix == new_prefix do
    {:leaf, new_prefix, new_value}
  end

  # Merge leafs that share some prefix, this will cause us to construct an extension followed by a branch
  defp trie_put_key({:leaf, [old_prefix_hd|_old_prefix_tl]=old_prefix, old_value}, [new_prefix_hd|_new_prefix_tl]=new_prefix, new_value, trie) when old_prefix_hd == new_prefix_hd do
    {matching_prefix, old_tl, new_tl} = ListHelper.overlap(old_prefix, new_prefix)

    {:ext, matching_prefix, build_branch([{old_tl, old_value}, {new_tl, new_value}], trie) |> Node.encode_node(trie)}
  end

  # Merge into a leaf with no matches (i.e. create a branch)
  defp trie_put_key({:leaf, old_prefix, old_value}, new_prefix, new_value, trie) do
    build_branch([{old_prefix, old_value}, {new_prefix, new_value}], trie)
  end

  # Merge right onto an extension node, we'll need to push this down to our value
  defp trie_put_key({:ext, shared_prefix, node_hash}, new_prefix, new_value, trie) when shared_prefix == new_prefix do
    {:ext, shared_prefix, Node.decode_trie(node_hash |> Trie.into(trie)) |> put_key([], new_value, trie)}
  end

  # Merge leafs that share some prefix, this will cause us to construct an extension followed by a branch
  defp trie_put_key({:ext, [old_prefix_hd|_old_prefix_tl]=old_prefix, old_value}, [new_prefix_hd|_new_prefix_tl]=new_prefix, new_value, trie) when old_prefix_hd == new_prefix_hd do
    {matching_prefix, old_tl, new_tl} = ListHelper.overlap(old_prefix, new_prefix)

    # TODO: Simplify logic?
    if old_tl == [] do
      # We are merging directly into an ext node (frustrating!)
      # Since ext nodes must be followed by branches, let's just merge
      # the new value into the branch
      old_trie = old_value |> Trie.into(trie) |> Node.decode_trie
      new_encoded_trie = put_key(old_trie, new_tl, new_value, trie) |> Node.encode_node(trie)

      {:ext, matching_prefix, new_encoded_trie}
    else
      # TODO: Handle when we need to add an extension after this
      # TODO: Standardize with below
      first = case old_tl do
        # [] -> {16, {:encoded, old_value}} # TODO: Is this right?
        [h|[]] -> {h, {:encoded, old_value}}
        [h|t] ->
          ext_encoded = {:ext, t, old_value} |> Node.encode_node(trie)

          {h, {:encoded, ext_encoded}}
      end

      {:ext, matching_prefix, build_branch([first, {new_tl, new_value}], trie) |> Node.encode_node(trie)}
    end
  end

  # Merge into a ext with no matches (i.e. create a branch)
  defp trie_put_key({:ext, old_prefix, old_value}, new_prefix, new_value, trie) do
    # TODO: Standardize with above
    first = case old_prefix do
      # [] -> {16, {:encoded, old_value}} # TODO: Is this right?
      [h|[]] -> {h, {:encoded, old_value}}
      [h|t] ->
        ext_encoded = {:ext, t, old_value} |> Node.encode_node(trie)
        {h, {:encoded, ext_encoded}}
    end
    build_branch([first, {new_prefix, new_value}], trie)
  end

  # Merge into a branch with empty prefix to store branch value
  defp trie_put_key({:branch, branches}, [], value, _trie) when length(branches) == 17 do
    {:branch, List.replace_at(branches, 16, value)}
  end

  # Merge down a branch node (recursively)
  defp trie_put_key({:branch, branches}, [prefix_hd|prefix_tl], value, trie) do
    {:branch,
      List.update_at(branches, prefix_hd, fn branch ->
        branch_node = branch |> Trie.into(trie) |> Node.decode_trie

        # Maybe this one?
        put_key(branch_node, prefix_tl, value, trie) |> Node.encode_node(trie)
      end)
    }
  end

  # Merge into empty to create a leaf
  defp trie_put_key(:empty, prefix, value, _trie) do
    {:leaf, prefix, value}
  end

  # Builds a branch node with starter values
  defp build_branch(branch_options, trie) do
    base = {:branch, (for _ <- 0..15, do: @empty_branch) ++ [<<>>]}

    Enum.reduce(branch_options, base,
        fn
          ({prefix, {:encoded, value}}, {:branch, branches}) ->
            {:branch, List.replace_at(branches, prefix, value)}

          ({prefix, value}, acc) ->
            put_key(acc, prefix, value, trie)
        end
    )
  end

end