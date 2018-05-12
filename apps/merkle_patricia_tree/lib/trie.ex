defmodule MerklePatriciaTree.Trie do
  @moduledoc File.read!("#{__DIR__}/../README.md")

  alias ExthCrypto.Hash.Keccak
  alias MerklePatriciaTree.Trie.{Helper, Builder, Destroyer, Node, Storage}
  alias MerklePatriciaTree.{DB, ListHelper}

  defstruct db: nil, root_hash: nil

  @type root_hash :: binary()

  @type t :: %__MODULE__{
          db: DB.db(),
          root_hash: root_hash
        }

  @type key :: binary() | [integer()]

  @empty_trie <<>>
  @empty_trie_root_hash @empty_trie |> ExRLP.encode() |> Keccak.kec()

  @doc """
  Returns the canonical empty trie.

  Note: this root hash will not be accessible unless you have stored
  the result in a db. If you are initializing a new trie, instead of
  checking a result is empty, it's strongly recommended you use
  `Trie.new(db).root_hash`.

  ## Examples

      iex> MerklePatriciaTree.Trie.empty_trie_root_hash()
      <<86, 232, 31, 23, 27, 204, 85, 166, 255, 131, 69, 230, 146, 192, 248, 110, 91, 72, 224, 27, 153, 108, 173, 192, 1, 98, 47, 181, 227, 99, 180, 33>>
  """
  @spec empty_trie_root_hash() :: root_hash
  def empty_trie_root_hash(), do: @empty_trie_root_hash

  @doc """
  Contructs a new trie.

  ## Examples

    iex> MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db(:trie_test_1))
    %MerklePatriciaTree.Trie{db: {MerklePatriciaTree.DB.ETS, :trie_test_1}, root_hash: <<86, 232, 31, 23, 27, 204, 85, 166, 255, 131, 69, 230, 146, 192, 248, 110, 91, 72, 224, 27, 153, 108, 173, 192, 1, 98, 47, 181, 227, 99, 180, 33>>}

    iex> MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db(:trie_test_2), <<1, 2, 3>>)
    %MerklePatriciaTree.Trie{db: {MerklePatriciaTree.DB.ETS, :trie_test_2}, root_hash: <<241, 136, 94, 218, 84, 183, 160, 83, 49, 140, 212, 30, 32, 147, 34, 13, 171, 21, 214, 83, 129, 177, 21, 122, 54, 51, 168, 59, 253, 92, 146, 57>>}

    iex> trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.DB.LevelDB.init("/tmp/#{
    MerklePatriciaTree.Test.random_string(20)
  }"), <<1, 2, 3>>)
    iex> trie.root_hash
    <<241, 136, 94, 218, 84, 183, 160, 83, 49, 140, 212, 30, 32, 147, 34,
      13, 171, 21, 214, 83, 129, 177, 21, 122, 54, 51, 168, 59, 253, 92,
      146, 57>>
    iex> {db, _db_ref} = trie.db
    iex> db
    MerklePatriciaTree.DB.LevelDB
  """
  @spec new(DB.db(), root_hash) :: t()
  def new(db = {_, _}, root_hash \\ @empty_trie) do
    %__MODULE__{db: db, root_hash: root_hash} |> store
  end

  @doc """
  Moves trie down to be rooted at `next_node`,
  this is effectively (and literally) just changing
  the root_hash to `next_node`.
  Used for trie traversal (ext and branch nodes) and
  for creating new tries with the same underlying db.
  """
  def into(next_node, trie) do
    %{trie | root_hash: next_node}
  end

  @doc """
  Given a trie, returns the value associated with key.
  """
  @spec get(t(), key()) :: binary() | nil
  def get(trie, key) do
    do_get(trie, Helper.get_nibbles(key))
  end

  @spec do_get(t() | nil, [integer()]) :: binary() | nil
  defp do_get(nil, _), do: nil

  defp do_get(trie, nibbles = [nibble | rest]) do
    # Let's decode `c(I, i)`

    case Node.decode_trie(trie) do
      # No node, bail
      :empty ->
        nil

      # Leaf node
      {:leaf, prefix, value} ->
        if prefix == nibbles,
          do: value,
          else: nil

      # Extension, continue walking trie if we match
      {:ext, shared_prefix, next_node} ->
        case ListHelper.get_postfix(nibbles, shared_prefix) do
          # Did not match extension node
          nil ->
            nil

          rest ->
            next_node |> into(trie) |> do_get(rest)
        end

      # Branch node
      {:branch, branches} ->
        case Enum.at(branches, nibble) do
          [] -> nil
          node_hash -> node_hash |> into(trie) |> do_get(rest)
        end
    end
  end

  defp do_get(trie, []) do
    # No prefix left, its either branch or leaf node
    case Node.decode_trie(trie) do
      # In branch node value is always the last element
      {:branch, branches} ->
        List.last(branches)

      {:leaf, [], v} ->
        v

      _ ->
        nil
    end
  end

  @doc """
  Updates a trie by setting key equal to value. If value is nil,
  we will instead remove `key` from the trie.
  """
  @spec update(t(), key(), ExRLP.t() | nil) :: t()
  def update(trie, key, nil), do: remove(trie, key)

  def update(trie, key, value) do
    key_nibbles = Helper.get_nibbles(key)
    # We're going to recursively walk toward our key,
    # then we'll add our value (either a new leaf or the value
    # on a branch node), then we'll walk back up the tree and
    # update all previous nodes.
    # This may require changing the type of the node.
    trie
    |> Node.decode_trie()
    |> Builder.put_key(key_nibbles, value, trie)
    |> Node.encode_node(trie)
    |> into(trie)
    |> store
  end

  @doc """
  Removes `key` from the `trie`.
  """
  @spec remove(t(), key()) :: t()
  def remove(trie, key) do
    key_nibbles = Helper.get_nibbles(key)

    trie
    |> Node.decode_trie()
    |> Destroyer.remove_key(key_nibbles, trie)
    |> Node.encode_node(trie)
    |> into(trie)
    |> store
  end

  def store(trie) do
    rlp = rlp_encode(trie.root_hash)

    # Let's check if it is RLP or Keccak-256 hash.
    # Keccak-256 is always 32-bytes.
    if byte_size(rlp) < Storage.max_rlp_len() do
      # It is RLP, so we need to calc KEC-256 and
      # store it in the database.
      kec = Storage.store(rlp, trie.db)
      %{trie | root_hash: kec}
    else
      # It is SHA3/Keccak-256,
      # so we know it is already stored in the DB.
      trie
    end
  end

  # Encodes `x` in RLP if it isn't already encoded.
  # And it is definitely not encoded if it is `<<>>` or not a binary (e.g. array).
  defp rlp_encode(x) when not is_binary(x) or x == <<>>, do: ExRLP.encode(x)
  defp rlp_encode(x), do: x
end
