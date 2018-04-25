defmodule MerklePatriciaTree.ListHelper do
  @moduledoc """
  Helpers for navigating lists, specifically for
  finding shared prefixes and postfixes.
  """

  @doc """
  Returns the post of list A if starts with list B, otherwise nil

  ## Examples

    iex> MerklePatriciaTree.ListHelper.get_postfix([1,2,3], [1,2])
    [3]

    iex> MerklePatriciaTree.ListHelper.get_postfix([1,2,3,4], [1,2])
    [3,4]

    iex> MerklePatriciaTree.ListHelper.get_postfix([1,2,3,4], [1])
    [2,3,4]

    iex> MerklePatriciaTree.ListHelper.get_postfix([1,2,3,4], [0,1])
    nil

    iex> MerklePatriciaTree.ListHelper.get_postfix([1,2,3,4], [])
    [1,2,3,4]

    iex> MerklePatriciaTree.ListHelper.get_postfix([1,2], [1,2,3])
    nil

    iex> MerklePatriciaTree.ListHelper.get_postfix([], [])
    []
  """
  @spec get_postfix([integer()], [integer()]) :: [integer()] | nil
  def get_postfix([h0 | t0], [h1 | t1]) do
    if h0 == h1 do
      get_postfix(t0, t1)
    else
      nil
    end
  end

  def get_postfix(l, []), do: l
  def get_postfix([], [_ | _]), do: nil

  @doc """
  Returns the overlap of two lists in terms of a shared prefix, then the relative postfixes

  ## Examples

    iex> MerklePatriciaTree.ListHelper.overlap([1,2,3], [1,2])
    {[1,2],[3],[]}

    iex> MerklePatriciaTree.ListHelper.overlap([1,2,3], [1,2,3,4])
    {[1,2,3],[],[4]}

    iex> MerklePatriciaTree.ListHelper.overlap([1,2,3], [2,3,4])
    {[],[1,2,3],[2,3,4]}

    iex> MerklePatriciaTree.ListHelper.overlap([], [2,3,4])
    {[],[],[2,3,4]}

    iex> MerklePatriciaTree.ListHelper.overlap([1,2,3], [])
    {[],[1,2,3],[]}

    iex> MerklePatriciaTree.ListHelper.overlap([15, 10, 5, 11], [15, 11, 1, 14])
    {[15], [10, 5, 11], [11, 1, 14]}
  """
  @spec overlap([integer()], [integer()]) :: {[integer()], [integer()], [integer()]}
  def overlap([], b = [_ | _]), do: {[], [], b}
  def overlap(a = [_ | _], []), do: {[], a, []}
  def overlap([], []), do: {[], [], []}

  def overlap([a0 | a], [b0 | b]) when a0 == b0 do
    {o1, a1, b1} = overlap(a, b)
    {[a0 | o1], a1, b1}
  end

  def overlap(a, b), do: {[], a, b}
end
