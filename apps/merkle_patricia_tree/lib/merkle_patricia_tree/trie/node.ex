defmodule MerklePatriciaTree.Trie.Node do
  @moduledoc """
  This module encodes and decodes nodes from a
  trie encoding back into RLP form. We effectively implement
  `c(I, i)` from the Yellow Paper.
  """

  alias MerklePatriciaTree.Trie.Storage
  alias MerklePatriciaTree.{HexPrefix, Trie}

  @type trie_node ::
          :empty
          | {:leaf, [integer()], binary()}
          | {:ext, [integer()], binary()}
          | {:branch, [binary()]}

  defguardp is_branch(nodes) when length(nodes) == 17

  @doc """
  Given a node, this function will encode the node
  and put the value to storage (for nodes that are
  greater than 32 bytes encoded). This implements
  `c(I, i)`, Eq.(193) of the Yellow Paper.

  ## Examples

      iex> trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      iex> MerklePatriciaTree.Trie.Node.encode_node(:empty, trie)
      <<>>

      iex> trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      iex> MerklePatriciaTree.Trie.Node.encode_node({:leaf, [5,6,7], "ok"}, trie)
      ["5g", "ok"]

      iex> trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      iex> MerklePatriciaTree.Trie.Node.encode_node({:branch, [<<>>, <<>>, <<>>, <<>>, <<>>, <<>>, <<>>, <<>>, <<>>, <<>>, <<>>, <<>>, <<>>, <<>>, <<>>, <<>>, <<>>]}, trie)
      ["", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", ""]

      iex> trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      iex> MerklePatriciaTree.Trie.Node.encode_node({:ext, [1, 2, 3], <<>>}, trie)
      [<<17, 35>>, ""]
  """
  @spec encode_node(trie_node, Trie.t()) :: binary()
  def encode_node(trie_node, trie) do
    trie_node
    |> encode_node_type()
    |> Storage.put_node(trie)
  end

  defp encode_node_type({:leaf, key, value}) do
    [HexPrefix.encode({key, true}), value]
  end

  defp encode_node_type({:branch, nodes}) when is_branch(nodes) do
    nodes
  end

  defp encode_node_type({:ext, shared_prefix, next_node}) do
    [HexPrefix.encode({shared_prefix, false}), next_node]
  end

  defp encode_node_type(:empty) do
    <<>>
  end

  @doc """
  Decodes the root of a given trie, effectively
  inverting the encoding from `c(I, i)` defined in
  Eq.(179) of the Yellow Paper.

  ## Examples

      iex> MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db(), <<128>>)
      iex> |> MerklePatriciaTree.Trie.Node.decode_trie()
      :empty

      iex> MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db(), <<198, 130, 53, 103, 130, 111, 107>>)
      iex> |> MerklePatriciaTree.Trie.Node.decode_trie()
      {:leaf, [5,6,7], "ok"}

      iex> MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db(), <<209, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128>>)
      iex> |> MerklePatriciaTree.Trie.Node.decode_trie()
      {:branch, [<<>>, <<>>, <<>>, <<>>, <<>>, <<>>, <<>>, <<>>, <<>>, <<>>, <<>>, <<>>, <<>>, <<>>, <<>>, <<>>, <<>>]}

      iex> MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db(), <<196, 130, 17, 35, 128>>)
      iex> |> MerklePatriciaTree.Trie.Node.decode_trie()
      {:ext, [1, 2, 3], <<>>}
  """
  @spec decode_trie(Trie.t()) :: trie_node
  def decode_trie(trie) do
    case Storage.get_node(trie) do
      nil ->
        :empty

      <<>> ->
        :empty

      # Empty branch node
      [] ->
        :empty

      :not_found ->
        :empty

      node ->
        decode_node(node)
    end
  end

  defp decode_node(nodes) when is_branch(nodes) do
    {:branch, nodes}
  end

  # Extension or leaf node
  defp decode_node([hp_key, value]) do
    {prefix, is_leaf} = HexPrefix.decode(hp_key)
    type = if is_leaf, do: :leaf, else: :ext
    {type, prefix, value}
  end
end
