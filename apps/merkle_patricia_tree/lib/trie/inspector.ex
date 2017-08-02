defmodule MerklePatriciaTree.Trie.Inspector do
  @moduledoc """
  A simple module to inspect and print the structure
  of tries.
  """
  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.Trie.Node
  alias MerklePatriciaTree.Trie.Helper
  require Logger

  @doc """
  Returns all values from a trie.

  ## Examples

      iex> MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...>   |> MerklePatriciaTree.Trie.update("type", "fighter")
      ...>   |> MerklePatriciaTree.Trie.update("name", "bob")
      ...>   |> MerklePatriciaTree.Trie.update("nationality", "usa")
      ...>   |> MerklePatriciaTree.Trie.update("nato", "strong")
      ...>   |> MerklePatriciaTree.Trie.update((for x <- 1..100, into: <<>>, do: <<x::8>>), (for x <- 1..100, into: <<>>, do: <<x*2::8>>))
      ...>   |> MerklePatriciaTree.Trie.Inspector.all_values()
      [
        {(for x <- 1..100, into: <<>>, do: <<x::8>>), (for x <- 1..100, into: <<>>, do: <<x*2::8>>)},
        {"name", "bob"},
        {"nationality", "usa"},
        {"nato", "strong"},
        {"type", "fighter"},
      ]
  """
  @spec all_values(Trie.t) :: [{binary(), binary()}]
  def all_values(trie) do
    get_trie_value(trie, <<>>)
  end

  @spec get_trie_value(Trie.t, binary()) :: [{binary(), binary()}]
  defp get_trie_value(trie, prefix) do
    case Node.decode_trie(trie) do
      :empty -> []
      {:leaf, k, v} -> [{merge_prefix(prefix, k), v}]
      {:ext, k, v} -> get_trie_value(%{trie| root_hash: v}, merge_prefix(prefix, k))
      {:branch, branches} ->
        branch_value = List.last(branches) # TODO: We need to fix nil branch value!
        base = if branch_value != <<>>, do: [{prefix, branch_value}], else: []

        Enum.reduce(0..15, base, fn (el, values) ->
          branch_root_hash = Enum.at(branches, el)
          branch_prefix = <<prefix::bitstring, el::size(4)>>

          values ++ get_trie_value(%{trie| root_hash: branch_root_hash}, branch_prefix)
        end)
    end
  end

  defp merge_prefix(prefix, key) do
    encoded_key = Helper.get_binary(key)

    <<prefix::bitstring, encoded_key::bitstring>>
  end

  @doc """
  Returns all keys from a trie.

  Note: this simply calls `all_values/1` and returns
  the first value of all tuples.

  ## Examples

      iex> MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...>   |> MerklePatriciaTree.Trie.update("type", "fighter")
      ...>   |> MerklePatriciaTree.Trie.update("name", "bob")
      ...>   |> MerklePatriciaTree.Trie.update("nationality", "usa")
      ...>   |> MerklePatriciaTree.Trie.update("nato", "strong")
      ...>   |> MerklePatriciaTree.Trie.update((for x <- 1..100, into: <<>>, do: <<x::8>>), (for x <- 1..100, into: <<>>, do: <<x*2::8>>))
      ...>   |> MerklePatriciaTree.Trie.Inspector.all_keys()
      [
        (for x <- 1..100, into: <<>>, do: <<x::8>>),
        "name",
        "nationality",
        "nato",
        "type",
      ]
  """
  @spec all_keys(Trie.t) :: [binary()]
  def all_keys(trie) do
    trie |> all_values |> Enum.map(fn {k,_v} -> k end)
  end

  @doc """
  Prints a visual depiction of a trie, returns trie itself.

  TODO: Test, possibly.
  """
  @spec inspect_trie(Trie.t) :: Trie.t
  def inspect_trie(trie) do
    IO.puts("~~~Trie~~~")
    IO.puts(do_inspect_trie(trie, 0))
    IO.puts("~~~/Trie/~~~\n")

    trie
  end

  defp do_inspect_trie(trie, depth, prefix \\ "") do
    whitespace = if depth > 0, do: for _ <- 1..(2*depth), do: " ", else: ""
    trie_node = Node.decode_trie(trie)
    node_info = inspect_trie_node(trie_node, trie, depth)
    "#{whitespace}#{prefix}Node: #{node_info}"
  end

  defp inspect_trie_node(:empty, _trie, _depth) do
    "<empty>"
  end

  defp inspect_trie_node({:leaf, k, v}, _trie, _depth) do
    "leaf (#{k |> inspect}=#{v |> inspect})"
  end

  defp inspect_trie_node({:ext, shared_prefix, v}, trie, depth) do
    sub = do_inspect_trie(%{trie| root_hash: v}, depth + 1)

    "ext (prefix: #{shared_prefix |> inspect})\n#{sub}"
  end

  defp inspect_trie_node({:branch, branches}, trie, depth) do
    base = "branch (value: #{List.last(branches) |> inspect})"

    Enum.reduce(0..15, base, fn (el, acc) ->
      acc <> "\n" <> do_inspect_trie(%{trie| root_hash: Enum.at(branches, el)}, depth + 1, "[#{el}] ")
    end)
  end

  @doc """
  Helper function to print an instruction message.
  """
  def inspect(msg, prefix) do
    Logger.debug(inspect [prefix, ":", msg])

    msg
  end
end
