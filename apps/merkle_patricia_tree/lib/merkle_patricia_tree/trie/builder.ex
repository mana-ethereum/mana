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

  import MerklePatriciaTree.ListHelper, only: [overlap: 2]

  alias MerklePatriciaTree.TrieStorage
  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.Trie.Node

  @empty_branch <<>>

  @doc """
  Adds a key-value pair to a given trie.

  This may radically change the structure of the trie.
  """
  @spec put_key(Node.trie_node(), Trie.key(), ExRLP.t(), Storage.t()) :: Node.trie_node()
  def put_key(trie_node, key, value, trie) do
    trie_put_key(trie_node, key, value, trie)
  end

  # Merge into a leaf with identical key (overwrite)
  defp trie_put_key({:leaf, old_prefix, _value}, new_prefix, new_value, _trie)
       when old_prefix == new_prefix do
    {:leaf, new_prefix, new_value}
  end

  # Merge leafs that share some prefix,
  # this will cause us to construct an extension followed by a branch.
  defp trie_put_key(
         {:leaf, [old_prefix_hd | _old_prefix_tl] = old_prefix, old_value},
         [new_prefix_hd | _new_prefix_tl] = new_prefix,
         new_value,
         trie
       )
       when old_prefix_hd == new_prefix_hd do
    {matching_prefix, old_tl, new_tl} = overlap(old_prefix, new_prefix)

    branch =
      [{old_tl, old_value}, {new_tl, new_value}]
      |> build_branch(trie)
      |> TrieStorage.put_node(trie)

    {:ext, matching_prefix, branch}
  end

  # Merge into a leaf with no matches (i.e. create a branch)
  defp trie_put_key({:leaf, old_prefix, old_value}, new_prefix, new_value, trie) do
    build_branch([{old_prefix, old_value}, {new_prefix, new_value}], trie)
  end

  # Merge into a branch with empty prefix to store branch value
  defp trie_put_key({:branch, nodes}, [], value, _trie) when length(nodes) == 17 do
    {:branch, List.replace_at(nodes, 16, value)}
  end

  # Merge down a branch node (recursively)
  defp trie_put_key({:branch, nodes}, [prefix_hd | prefix_tl], value, trie) do
    {:branch,
     List.update_at(nodes, prefix_hd, fn branch ->
       node =
         branch
         |> TrieStorage.into(trie)
         |> TrieStorage.fetch_node()

       # Insert the rest
       node
       |> put_key(prefix_tl, value, trie)
       |> TrieStorage.put_node(trie)
     end)}
  end

  # Merge into empty to create a leaf
  defp trie_put_key(:empty, prefix, value, _trie) do
    {:leaf, prefix, value}
  end

  # Merge exts that share some prefix,
  # this will cause us to construct an extension followed by a branch.
  defp trie_put_key(
         {:ext, [old_prefix_hd | _old_prefix_tl] = old_prefix, old_value},
         [new_prefix_hd | _new_prefix_tl] = new_prefix,
         new_value,
         trie
       )
       when old_prefix_hd == new_prefix_hd do
    {matching_prefix, old_tl, new_tl} = overlap(old_prefix, new_prefix)

    # We know that current `old_value` is a branch node because
    # extension nodes are always followed by branch nodes.
    # Now, lets see which one should go first.
    if old_tl == [] do
      # Ok, the `new_prefix` starts with the `old_prefix`.
      #
      # For example this could be the case when:
      # old_prefix = [1, 2]
      # new_prefix = [1, 2, 3]
      #
      # So the old one should go first followed by the new one.
      # In this case let's just merge the new value into the `old_branch`.

      # This is our decoded old branch trie.
      old_trie =
        old_value
        |> TrieStorage.into(trie)
        |> TrieStorage.fetch_node()

      # Recursively merge the new value into
      # the old branch trie.
      new_encoded_trie =
        old_trie
        |> put_key(new_tl, new_value, trie)
        |> TrieStorage.put_node(trie)

      {:ext, matching_prefix, new_encoded_trie}
    else
      # If we've got here then we know that
      # the `new_prefix` isn't prefixed by the `old_prefix`.
      #
      # This may happen, for example, when
      # we "insert" into the middle/beginning of the trie:
      # old_tl = [3]     <= overlap([1,2,3], [1,2])
      # old_tl = [1,2,3] <= overlap([1,2,3], [2,3,4])
      # old_tl = [1,2,3] <= overlap([1,2,3], [])
      #
      # So new node should come first followed by the old node,
      # which (as we already know) is a branch node.
      # In this case we need to construct a new "empty" branch node,
      # that may itself be placed "inside" another ext node,
      # (if there are 2 or more shared nibbles) and then we need to
      # (recursively) merge the old value into it.
      first =
        case old_tl do
          # No shared nibbles.
          # We need at least 2 for it to be the extension node.
          [h | []] ->
            # Here `h` is the nibble index inside
            # our new branch node where the `old_value` will be inserted.
            {h, {:encoded, old_value}}

          # They have some common/shared prefix nibbles.
          # So we need to "insert" an extension node.
          [h | t] ->
            ext_encoded = TrieStorage.put_node({:ext, t, old_value}, trie)
            {h, {:encoded, ext_encoded}}
        end

      branch =
        [first, {new_tl, new_value}]
        |> build_branch(trie)
        |> TrieStorage.put_node(trie)

      {:ext, matching_prefix, branch}
    end
  end

  # Merge into a ext with no matches (i.e. create a branch).
  defp trie_put_key({:ext, old_prefix, old_value}, new_prefix, new_value, trie) do
    first =
      case old_prefix do
        [h | []] ->
          {h, {:encoded, old_value}}

        [h | t] ->
          ext_encoded = TrieStorage.put_node({:ext, t, old_value}, trie)
          {h, {:encoded, ext_encoded}}
      end

    build_branch([first, {new_prefix, new_value}], trie)
  end

  # Builds a branch node with starter values.
  defp build_branch(options, trie) do
    base = {:branch, for(_ <- 0..15, do: @empty_branch) ++ [<<>>]}

    Enum.reduce(options, base, fn
      {prefix, {:encoded, value}}, {:branch, nodes} ->
        next_nodes = List.replace_at(nodes, prefix, value)
        {:branch, next_nodes}

      {prefix, value}, acc ->
        put_key(acc, prefix, value, trie)
    end)
  end
end
