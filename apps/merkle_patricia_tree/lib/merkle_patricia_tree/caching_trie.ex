defmodule MerklePatriciaTree.CachingTrie do
  alias MerklePatriciaTree.Trie

  alias MerklePatriciaTree.Trie.Builder
  alias MerklePatriciaTree.Trie.Destroyer
  alias MerklePatriciaTree.Trie.Fetcher
  alias MerklePatriciaTree.Trie.Helper
  alias MerklePatriciaTree.TrieStorage

  @behaviour MerklePatriciaTree.TrieStorage

  defstruct [
    :in_memory_trie,
    :trie,
    :db_changes
  ]

  @type db_changes :: %{binary() => binary()}

  @type t :: %__MODULE__{
          in_memory_trie: TrieStorage.t(),
          trie: TrieStorage.t(),
          db_changes: db_changes
        }

  @batch_size 1000

  def new(trie) do
    ets_db = MerklePatriciaTree.Test.random_ets_db()
    root_hash = TrieStorage.root_hash(trie)
    in_memory_trie = Trie.new(ets_db, root_hash)

    %__MODULE__{
      in_memory_trie: in_memory_trie,
      trie: trie,
      db_changes: %{}
    }
  end

  @impl true
  def root_hash(caching_trie) do
    TrieStorage.root_hash(caching_trie.in_memory_trie)
  end

  @impl true
  def set_root_hash(caching_trie, root_hash) do
    %{caching_trie | in_memory_trie: %{caching_trie.in_memory_trie | root_hash: root_hash}}
  end

  @impl true
  def fetch_node(caching_trie) do
    in_memory_node = TrieStorage.fetch_node(caching_trie.in_memory_trie)

    if in_memory_node == :empty do
      in_memory_root_hash = TrieStorage.root_hash(caching_trie.in_memory_trie)

      caching_trie.trie
      |> TrieStorage.set_root_hash(in_memory_root_hash)
      |> TrieStorage.fetch_node()
    else
      in_memory_node
    end
  end

  @impl true
  def put_node(node, caching_trie) do
    TrieStorage.put_node(node, caching_trie.in_memory_trie)
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
  def remove_subtrie_key(caching_trie, root_hash, key) do
    caching_subtrie = %{
      caching_trie
      | in_memory_trie: %{caching_trie.in_memory_trie | root_hash: root_hash}
    }

    updated_caching_subtrie = remove_key(caching_subtrie, key)

    {updated_caching_subtrie, caching_trie}
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
  def update_subtrie_key(caching_trie, root_hash, key, value) do
    caching_subtrie = %{
      caching_trie
      | in_memory_trie: %{caching_trie.in_memory_trie | root_hash: root_hash}
    }

    updated_caching_subtrie = update_key(caching_subtrie, key, value)

    {updated_caching_subtrie, caching_trie}
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
      TrieStorage.get_raw_key(caching_trie.trie, key)
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
    trie = %{caching_trie.trie | root_hash: caching_trie.in_memory_trie.root_hash}

    trie_updates = get_all_key_value_pairs_as_stream(caching_trie.in_memory_trie)
    db_updates = Stream.into(caching_trie.db_changes, [])
    all_updates = Stream.concat(trie_updates, db_updates)

    TrieStorage.put_batch_raw_keys!(trie, all_updates, @batch_size)

    new(trie)
  end

  @impl true
  def put_batch_raw_keys!(caching_trie, key_value_pairs, _batch_size) do
    updates = Map.new(key_value_pairs)

    updated_db_changes = Map.merge(caching_trie.db_changes, updates)

    %{caching_trie | db_changes: updated_db_changes}
  end

  @impl true
  def store(caching_trie) do
    in_memory_trie = caching_trie.in_memory_trie

    stored_in_memory_trie = TrieStorage.store(in_memory_trie)

    %{caching_trie | in_memory_trie: stored_in_memory_trie}
  end

  @impl true
  def into(next_node, caching_trie) do
    updated_in_memory_trie = %{caching_trie.in_memory_trie | root_hash: next_node}

    %{caching_trie | in_memory_trie: updated_in_memory_trie}
  end

  @impl true
  def permanent_db(caching_trie) do
    TrieStorage.permanent_db(caching_trie.trie)
  end

  @spec get_all_key_value_pairs_as_stream(TrieStorage.t()) :: Enumerable.t()
  defp get_all_key_value_pairs_as_stream(in_memory_trie) do
    {_db_module, db_ref} = in_memory_trie.db

    Stream.resource(
      fn ->
        :ets.match(db_ref, {:"$1", :"$2"}, @batch_size)
      end,
      fn
        {els, continuation} ->
          {els, continuation}

        continuation ->
          case :ets.match(continuation) do
            {els, continuation} -> {els, continuation}
            :"$end_of_table" -> {:halt, nil}
          end
      end,
      fn nil ->
        true = :ets.match_delete(db_ref, {:"$1", :"$2"})
      end
    )
    |> Stream.map(fn [key, value] -> {key, value} end)
  end
end
