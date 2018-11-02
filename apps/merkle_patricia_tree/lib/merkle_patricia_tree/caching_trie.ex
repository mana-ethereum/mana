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
    :trie_changes,
    :db_changes
  ]

  @type trie_change ::
          {:update, Trie.root_hash(), Trie.key(), ExRLP.t()}
          | {:remove, Trie.root_hash(), Trie.key()}
  @type db_changes :: %{binary() => binary()}

  @type t :: %__MODULE__{
          in_memory_trie: TrieStorage.t(),
          trie: TrieStorage.t(),
          trie_changes: [trie_change()],
          db_changes: db_changes
        }

  def new(trie) do
    ets_db = MerklePatriciaTree.Test.random_ets_db()
    root_hash = TrieStorage.root_hash(trie)
    in_memory_trie = Trie.new(ets_db, root_hash)

    %__MODULE__{
      in_memory_trie: in_memory_trie,
      trie: trie,
      trie_changes: [],
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
    trie = caching_trie.trie

    updated_trie =
      Enum.reduce(caching_trie.trie_changes, trie, fn trie_change, trie_acc ->
        case trie_change do
          {:update, root_hash, key, value} ->
            {_subtrie, trie} = TrieStorage.update_subtrie_key(trie_acc, root_hash, key, value)
            trie

          {:remove, root_hash, key} ->
            {_subtrie, trie} = TrieStorage.remove_subtrie_key(trie_acc, root_hash, key)
            trie
        end
      end)

    caching_trie.db_changes
    |> Map.to_list()
    |> Enum.each(fn {key, value} ->
      TrieStorage.put_raw_key!(updated_trie, key, value)
    end)

    new(updated_trie)
  end

  @impl true
  def put_batch_raw_keys!(caching_trie, key_value_pairs) do
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
end
