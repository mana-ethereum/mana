defmodule MerklePatriciaTree.CachingTrie do
  alias MerklePatriciaTree.Trie

  alias MerklePatriciaTree.Trie.Builder
  alias MerklePatriciaTree.Trie.Destroyer
  alias MerklePatriciaTree.Trie.Fetcher
  alias MerklePatriciaTree.Trie.Helper
  alias MerklePatriciaTree.Trie.Node
  alias MerklePatriciaTree.Trie.Storage

  @behaviour MerklePatriciaTree.TrieStorage

  defstruct [
    :in_memory_trie,
    :trie,
    :trie_changes,
    :db_changes
  ]

  @type trie_change ::
          {:update, Trie.root_hash(), Trie.key(), ExRLP.t()}
          | {:remove, Trie.root_hash(), Trie.key()}
  @type db_changes :: %{binary() => binary()}

  @type t :: %__MODULE__{
          in_memory_trie: Trie.t(),
          trie: Trie.t(),
          trie_changes: [trie_change()],
          db_changes: db_changes
        }

  def new(trie) do
    ets_db = MerklePatriciaTree.Test.random_ets_db()
    in_memory_trie = Trie.new(ets_db, trie.root_hash)

    %__MODULE__{
      in_memory_trie: in_memory_trie,
      trie: trie,
      trie_changes: [],
      db_changes: %{}
    }
  end

  @impl true
  def root_hash(caching_trie) do
    caching_trie.in_memory_trie.root_hash
  end

  @impl true
  def set_root_hash(caching_trie, root_hash) do
    %{caching_trie | in_memory_trie: %{caching_trie.in_memory_trie | root_hash: root_hash}}
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
    trie_change = {:remove, caching_trie.in_memory_trie.root_hash, key}

    updated_caching_trie =
      caching_trie
      |> fetch_node()
      |> Destroyer.remove_key(key_nibbles, caching_trie)
      |> put_node(caching_trie)
      |> into(caching_trie)
      |> store()

    %{updated_caching_trie | trie_changes: updated_caching_trie.trie_changes ++ [trie_change]}
  end

  @impl true
  def remove_subtrie_key(caching_trie, root_hash, key) do
    trie_change = {:remove, root_hash, key}

    caching_subtrie = %{
      caching_trie
      | in_memory_trie: %{caching_trie.in_memory_trie | root_hash: root_hash}
    }

    updated_caching_subtrie = remove_key(caching_subtrie, key)

    updated_caching_trie = %{
      caching_trie
      | trie_changes: caching_trie.trie_changes ++ [trie_change]
    }

    {updated_caching_subtrie, updated_caching_trie}
  end

  @impl true
  def update_key(caching_trie, key, value) do
    if is_nil(value) do
      remove_key(caching_trie, key)
    else
      key_nibbles = Helper.get_nibbles(key)
      trie_change = {:update, caching_trie.in_memory_trie.root_hash, key, value}
      # We're going to recursively walk toward our key,
      # then we'll add our value (either a new leaf or the value
      # on a branch node), then we'll walk back up the tree and
      # update all previous nodes.
      # This may require changing the type of the node.
      updated_caching_trie =
        caching_trie
        |> fetch_node()
        |> Builder.put_key(key_nibbles, value, caching_trie)
        |> put_node(caching_trie)
        |> into(caching_trie)
        |> store()

      %{updated_caching_trie | trie_changes: updated_caching_trie.trie_changes ++ [trie_change]}
    end
  end

  @impl true
  def update_subtrie_key(caching_trie, root_hash, key, value) do
    trie_change = {:update, root_hash, key, value}

    caching_subtrie = %{
      caching_trie
      | in_memory_trie: %{caching_trie.in_memory_trie | root_hash: root_hash}
    }

    updated_caching_subtrie = update_key(caching_subtrie, key, value)

    updated_caching_trie = %{
      caching_trie
      | trie_changes: caching_trie.trie_changes ++ [trie_change]
    }

    {updated_caching_subtrie, updated_caching_trie}
  end

  @impl true
  def put_raw_key!(caching_trie, key, value) do
    updated_db_changes = Map.put(caching_trie.db_changes, key, value)

    %{caching_trie | db_changes: updated_db_changes}
  end

  @impl true
  def get_raw_key(caching_trie, key) do
    cached_value = Map.get(caching_trie.db_changes, key)

    if is_nil(cached_value) do
      MerklePatriciaTree.DB.get(caching_trie.trie.db, key)
    else
      {:ok, cached_value}
    end
  end

  @impl true
  def get_key(caching_trie, key) do
    Fetcher.get(caching_trie, key)
  end

  @impl true
  def get_subtrie_key(caching_trie, root_hash, key) do
    caching_subtrie = %{
      caching_trie
      | in_memory_trie: %{caching_trie.in_memory_trie | root_hash: root_hash}
    }

    Fetcher.get(caching_subtrie, key)
  end

  @impl true
  def commit!(caching_trie) do
    trie = caching_trie.trie

    updated_trie =
      Enum.reduce(caching_trie.trie_changes, trie, fn trie_change, trie_acc ->
        case trie_change do
          {:update, root_hash, key, value} ->
            {_subtrie, trie} = Trie.update_subtrie_key(trie_acc, root_hash, key, value)
            trie

          {:remove, root_hash, key} ->
            {_subtrie, trie} = Trie.remove_subtrie_key(trie_acc, root_hash, key)
            trie
        end
      end)

    caching_trie.db_changes
    |> Map.to_list()
    |> Enum.each(fn {key, value} ->
      Trie.put_raw_key!(updated_trie, key, value)
    end)

    :ok
  end

  @impl true
  def store(caching_trie) do
    in_memory_trie = caching_trie.in_memory_trie
    rlp = Helper.rlp_encode(in_memory_trie.root_hash)

    # Let's check if it is RLP or Keccak-256 hash.
    if Storage.keccak_hash?(rlp) do
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
