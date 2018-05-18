defmodule MerklePatriciaTree.Trie.Verifier do
  @moduledoc """
  Function to verify the structure of a trie meets
  the spec as defined in Appendix D of the Yellow Paper.
  """

  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.Trie.Node

  @empty_branch Node.encode_node(:empty, nil)

  @doc """
  Runs simple tests to verify a trie matches general specs.

  We will check:

  1. Leafs have a non-empty value
  2. Leafs' and branch's value belong to a set of given values.
  3. Branches have at least two non-empty nodes.
  4. All sub-tries are valid.
  5. Ext's prefixes aren't blank.
  6. TODO: Ext's can't be extended.
  """
  @spec verify_trie(Trie.t(), [{binary(), binary()}]) :: :ok | {:error, String.t()}
  def verify_trie(trie, dict) do
    values = for {_, v} <- dict, do: v

    do_verify_trie(trie, dict, values)
  end

  defp do_verify_trie(trie, dict, values) do
    verify_node(Node.decode_trie(trie), trie, dict, values)
  end

  defp verify_node(:empty, _trie, _dict, _values), do: :ok

  defp verify_node({:leaf, k, v}, _trie, _dict, values) do
    if v == "" do
      {:error, "empty leaf value at #{inspect(k)}"}
    else
      if not Enum.member?(values, v) do
        {:error, "leaf value v does not appear in values (#{inspect(v)})"}
      else
        :ok
      end
    end
  end

  defp verify_node({:branch, all_branches}, trie, dict, values) do
    {v, branches} = List.pop_at(all_branches, 16)

    branch_tries = for branch <- branches, do: Trie.into(branch, trie)

    branches_well_formed =
      for branch_trie <- branch_tries do
        do_verify_trie(branch_trie, dict, values)
      end

    not_okay_branches = Enum.filter(branches_well_formed, &(&1 != :ok))

    if Enum.count(not_okay_branches) > 0 do
      {:error, "malformed branches: #{inspect(not_okay_branches)}"}
    else
      # All branches are technically okay, let's verify that

      # Let's verify we have at least one non-empty branch
      if Enum.count(branches, &(&1 != @empty_branch)) < 2 do
        {:error, "branch with only zero or one exits"}
      else
        # also check the value is okay
        if v != <<>> and not Enum.member?(values, v) do
          {:error, "branch value v does not appear in values (#{inspect(v)})"}
        else
          :ok
        end
      end
    end
  end

  defp verify_node({:ext, shared_prefix, node_hash}, trie, dict, values) do
    if shared_prefix == [] do
      {:error, "empty shared prefix"}
    else
      ext_trie = Trie.into(node_hash, trie)
      do_verify_trie(ext_trie, dict, values)

      # TODO: Check we can't extend the ext?
    end
  end
end
