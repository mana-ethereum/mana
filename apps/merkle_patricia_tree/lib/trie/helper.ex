defmodule MerklePatriciaTree.Trie.Helper do
  @moduledoc """
  Functions to help with manipulating or working
  with tries.
  """
  require Logger

  @doc """
  Returns the nibbles of a given binary as a list

  ## Examples

  iex> MerklePatriciaTree.Trie.Helper.get_nibbles(<<0x1e, 0x2f>>)
  [0x01, 0x0e, 0x02, 0x0f]

  iex> MerklePatriciaTree.Trie.Helper.get_nibbles(<<0x1::4, 0x02::4, 0x03::4>>)
  [1, 2, 3]

  iex> MerklePatriciaTree.Trie.Helper.get_nibbles(<<0x01, 0x02, 0x03>>)
  [0, 1, 0, 2, 0, 3]
  """
  @spec get_nibbles(binary()) :: [integer()]
  def get_nibbles(k), do: for(<<nibble::4 <- k>>, do: nibble)

  @doc """
  Returns the binary of a given a list of nibbles

  ## Examples

  iex> MerklePatriciaTree.Trie.Helper.get_binary([0x01, 0x0e, 0x02, 0x0f])
  <<0x1e, 0x2f>>

  iex> MerklePatriciaTree.Trie.Helper.get_binary([1, 2, 3])
  <<0x1::4, 0x02::4, 0x03::4>>

  iex> MerklePatriciaTree.Trie.Helper.get_binary([0, 1, 0, 2, 0, 3])
  <<0x01, 0x02, 0x03>>
  """
  @spec get_binary([integer()]) :: binary()
  def get_binary(l) do
    for x <- l, into: <<>>, do: <<x::4>>
  end
end
