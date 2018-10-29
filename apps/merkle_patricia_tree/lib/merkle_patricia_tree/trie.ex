defmodule MerklePatriciaTree.Trie do
  @moduledoc File.read!("#{__DIR__}/../../README.md")

  alias ExthCrypto.Hash.Keccak
  alias MerklePatriciaTree.DB
  alias MerklePatriciaTree.Trie.{Builder, Destroyer, Fetcher, Helper, Node, Storage}

  defstruct db: nil, root_hash: nil

  @behaviour MerklePatriciaTree.Storage

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

      iex> trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.DB.RocksDB.init("/tmp/#{
    MerklePatriciaTree.Test.random_string(20)
  }"), <<1, 2, 3>>)
      iex> trie.root_hash
      <<241, 136, 94, 218, 84, 183, 160, 83, 49, 140, 212, 30, 32, 147, 34,
        13, 171, 21, 214, 83, 129, 177, 21, 122, 54, 51, 168, 59, 253, 92,
        146, 57>>
      iex> {db, _db_ref} = trie.db
      iex> db
      MerklePatriciaTree.DB.RocksDB
  """
  @spec new(DB.db(), root_hash) :: t()
  def new(db = {_, _}, root_hash \\ @empty_trie) do
    %__MODULE__{db: db, root_hash: root_hash} |> store()
  end

  @impl true
  def fetch_node(trie) do
    Node.decode_trie(trie)
  end

  @impl true
  def put_node(node, trie) do
    Node.encode_node(node, trie)
  end

  @doc """
  Moves trie down to be rooted at `next_node`,
  this is effectively (and literally) just changing
  the root_hash to `next_node`.
  Used for trie traversal (ext and branch nodes) and
  for creating new tries with the same underlying db.
  """
  @impl true
  def into(next_node, trie) do
    %{trie | root_hash: next_node}
  end

  @doc """
  Given a trie, returns the value associated with key.
  """
  @impl true
  def get_key(trie, key) do
    Fetcher.get(trie, key)
  end

  @doc """
  Updates a trie by setting key equal to value.
  If value is nil, we will instead remove `key` from the trie.
  """

  @impl true
  def update_key(trie, key, value) do
    if is_nil(value) do
      remove_key(trie, key)
    else
      key_nibbles = Helper.get_nibbles(key)
      # We're going to recursively walk toward our key,
      # then we'll add our value (either a new leaf or the value
      # on a branch node), then we'll walk back up the tree and
      # update all previous nodes.
      # This may require changing the type of the node.
      trie
      |> fetch_node()
      |> Builder.put_key(key_nibbles, value, trie)
      |> put_node(trie)
      |> into(trie)
      |> store()
    end
  end

  @doc """
  Removes `key` from the `trie`.
  """
  @impl true
  def remove_key(trie, key) do
    key_nibbles = Helper.get_nibbles(key)

    trie
    |> fetch_node()
    |> Destroyer.remove_key(key_nibbles, trie)
    |> put_node(trie)
    |> into(trie)
    |> store()
  end

  @impl true
  def store(trie) do
    rlp = Helper.rlp_encode(trie.root_hash)

    # Let's check if it is RLP or Keccak-256 hash.
    if Storage.keccak_hash?(rlp) do
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
end
