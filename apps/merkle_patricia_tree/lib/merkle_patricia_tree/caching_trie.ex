defmodule MerklePatriciaTree.CachingTrie do
  alias MerklePatriciaTree.Trie

  alias MerklePatriciaTree.Trie.Builder
  alias MerklePatriciaTree.Trie.Destroyer
  alias MerklePatriciaTree.Trie.Fetcher
  alias MerklePatriciaTree.Trie.Helper
  alias MerklePatriciaTree.Trie.Node
  alias MerklePatriciaTree.Trie.Storage

  @behaviour MerklePatriciaTree.StorageBehaviour

  defstruct [
    :in_memory_trie,
    :trie
  ]

  @type t :: %__MODULE__{
          in_memory_trie: Trie.t(),
          trie: Trie.t()
        }

  def new(trie) do
    ets_db = MerklePatriciaTree.Test.random_ets_db()
    in_memory_trie = Trie.new(ets_db, trie.root_hash)

    %__MODULE__{
      in_memory_trie: in_memory_trie,
      trie: trie
    }
  end

  @impl true
  def fetch_node(caching_trie) do
    in_memory_node = Node.decode_trie(caching_trie.in_memory_trie)

    if in_memory_node == :empty do
      trie = %{caching_trie.trie | root_hash: caching_trie.in_memory_trie.root_hash}

      Node.decode_trie(trie)
    else
      in_memory_node
    end
  end

  @impl true
  def put_node(node, caching_trie) do
    Node.encode_node(node, caching_trie.in_memory_trie)
  end

  @impl true
  def remove_key(caching_trie, key) do
    key_nibbles = Helper.get_nibbles(key)

    caching_trie
    |> fetch_node()
    |> Destroyer.remove_key(key_nibbles, caching_trie)
    |> put_node(caching_trie)
    |> into(caching_trie)
    |> store()
  end

  @impl true
  def update_key(caching_trie, key, value) do
    if is_nil(value) do
      remove_key(caching_trie, key)
    else
      key_nibbles = Helper.get_nibbles(key)
      # We're going to recursively walk toward our key,
      # then we'll add our value (either a new leaf or the value
      # on a branch node), then we'll walk back up the tree and
      # update all previous nodes.
      # This may require changing the type of the node.
      caching_trie
      |> fetch_node()
      |> Builder.put_key(key_nibbles, value, caching_trie)
      |> put_node(caching_trie)
      |> into(caching_trie)
      |> store()
    end
  end

  @impl true
  def get_key(caching_trie, key) do
    Fetcher.get(caching_trie, key)
  end

  @impl true
  def store(caching_trie) do
    in_memory_trie = caching_trie.in_memory_trie
    rlp = Helper.rlp_encode(in_memory_trie.root_hash)

    # Let's check if it is RLP or Keccak-256 hash.
    # Keccak-256 is always 32-bytes.
    if byte_size(rlp) < Storage.max_rlp_len() do
      # It is RLP, so we need to calc KEC-256 and
      # store it in the database.
      kec = Storage.store(rlp, in_memory_trie.db)
      updated_in_memory_trie = %{in_memory_trie | root_hash: kec}
      %{caching_trie | in_memory_trie: updated_in_memory_trie}
    else
      # It is SHA3/Keccak-256,
      # so we know it is already stored in the DB.
      caching_trie
    end
  end

  @impl true
  def into(next_node, caching_trie) do
    updated_in_memory_trie = %{caching_trie.in_memory_trie | root_hash: next_node}

    %{caching_trie | in_memory_trie: updated_in_memory_trie}
  end
end
