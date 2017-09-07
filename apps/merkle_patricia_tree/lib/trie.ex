defmodule MerklePatriciaTree.Trie do
  @moduledoc File.read!("#{__DIR__}/../README.md")

  alias MerklePatriciaTree.Trie.Helper
  alias MerklePatriciaTree.Trie.Builder
  alias MerklePatriciaTree.Trie.Destroyer
  alias MerklePatriciaTree.Trie.Node
  alias MerklePatriciaTree.DB
  alias MerklePatriciaTree.ListHelper

  defstruct [db: nil, root_hash: nil]

  @type root_hash :: binary()

  @type t :: %__MODULE__{
    db: DB.db,
    root_hash: root_hash
  }

  @type key :: binary()

  @empty_trie MerklePatriciaTree.Trie.Node.encode_node(:empty, nil)

  @doc """
  Returns the canonical empty trie.

  ## Examples

      iex> %MerklePatriciaTree.Trie{root_hash: MerklePatriciaTree.Trie.empty_trie} |> MerklePatriciaTree.Trie.Node.decode_trie()
      :empty
  """
  @spec empty_trie() :: root_hash
  def empty_trie(), do: @empty_trie

  @doc """
  Contructs a new unitialized trie.

  ## Examples

    iex> MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db(:trie_test_1))
    %MerklePatriciaTree.Trie{db: {MerklePatriciaTree.DB.ETS, :trie_test_1}, root_hash: <<197, 210, 70, 1, 134, 247, 35, 60, 146, 126, 125, 178, 220, 199, 3, 192, 229, 0, 182, 83, 202, 130, 39, 59, 123, 250, 216, 4, 93, 133, 164, 112>>}

    iex> MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db(:trie_test_2), <<1, 2, 3>>)
    %MerklePatriciaTree.Trie{db: {MerklePatriciaTree.DB.ETS, :trie_test_2}, root_hash: <<241, 136, 94, 218, 84, 183, 160, 83, 49, 140, 212, 30, 32, 147, 34, 13, 171, 21, 214, 83, 129, 177, 21, 122, 54, 51, 168, 59, 253, 92, 146, 57>>}

    iex> trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.DB.LevelDB.init("/tmp/#{MerklePatriciaTree.Test.random_string(20)}"), <<1, 2, 3>>)
    iex> trie.root_hash
    <<241, 136, 94, 218, 84, 183, 160, 83, 49, 140, 212, 30, 32, 147, 34,
      13, 171, 21, 214, 83, 129, 177, 21, 122, 54, 51, 168, 59, 253, 92,
      146, 57>>
    iex> {db, _db_ref} = trie.db
    iex> db
    MerklePatriciaTree.DB.LevelDB
  """
  @spec new(DB.db, root_hash) :: __MODULE__.t
  def new(db={_, _}, root_hash \\ @empty_trie) do
    %__MODULE__{db: db, root_hash: root_hash} |> store
  end

  @doc """
  Moves trie down to be rooted at `next_node`,
  this is effectively (and literally) just changing
  the root_hash to `node_hash`.
  """
  def into(next_node, trie) do
    %{trie| root_hash: next_node}
  end

  @doc """
  Given a trie, returns the value associated with key.
  """
  @spec get(__MODULE__.t, __MODULE__.key) :: binary() | nil
  def get(trie, key) do
    do_get(trie, Helper.get_nibbles(key))
  end

  @spec do_get(__MODULE__.t | nil, [integer()]) :: binary() | nil
  defp do_get(nil, _), do: nil
  defp do_get(trie, nibbles=[nibble| rest]) do
    # Let's decode `c(I, i)`

    case Node.decode_trie(trie) do
      :empty -> nil # no node, bail
      {:branch, branches} ->
        # branch node
        case Enum.at(branches, nibble) do
          [] -> nil
          node_hash -> node_hash |> into(trie) |> do_get(rest)
        end
      {:leaf, prefix, value} ->
        # leaf, value is second value if match first
        case nibbles do
          ^prefix -> value
          _ -> nil
        end
      {:ext, shared_prefix, next_node} ->
        # extension, continue walking tree if we match
        case ListHelper.get_postfix(nibbles, shared_prefix) do
          nil -> nil # did not match extension node
          rest -> next_node |> into(trie) |> do_get(rest)
        end
    end
  end

  defp do_get(trie, []) do
    # Only branch nodes can have values for a nil lookup
    case Node.decode_trie(trie) do
      {:branch, branches} -> List.last(branches)
      {:leaf, [], v} -> v
      _ -> nil
    end
  end

  @doc """
  Updates a trie by setting key equal to value. If value is nil,
  we will instead remove `key` from the trie.
  """
  @spec update(__MODULE__.t, __MODULE__.key, ExRLP.t | nil) :: __MODULE__.t
  def update(trie, key, nil) do
    Node.decode_trie(trie)
    |> Destroyer.remove_key(Helper.get_nibbles(key), trie)
    |> Node.encode_node(trie)
    |> into(trie)
    |> store
  end

  def update(trie, key, value) do
    # We're going to recursively walk toward our key,
    # then we'll add our value (either a new leaf or the value
    # on a branch node), then we'll walk back up the tree and
    # update all previous ndes. This may require changing the
    # type of the node.
    Node.decode_trie(trie)
    |> Builder.put_key(Helper.get_nibbles(key), value, trie)
    |> Node.encode_node(trie)
    |> into(trie)
    |> store
  end

  def store(trie) do
    root_hash = if not is_binary(trie.root_hash), do: ExRLP.encode(trie.root_hash), else: trie.root_hash

    if byte_size(root_hash) < MerklePatriciaTree.Trie.Storage.max_rlp_len do
      %{trie | root_hash: root_hash |> MerklePatriciaTree.Trie.Storage.store(trie.db)}
    else
      trie
    end
  end

end
