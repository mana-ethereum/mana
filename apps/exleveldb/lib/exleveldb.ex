defmodule Exleveldb do
  @type db_location    :: binary
  @type db_reference   :: binary
  @type open_options() :: [{:create_if_missing, boolean} |
                           {:error_if_exists, boolean} |
                           {:write_buffer_size, pos_integer} |
                           {:block_size, pos_integer} |
                           {:sst_block_size, pos_integer} |
                           {:block_restart_interval, pos_integer} |
                           {:block_size_steps, pos_integer} |
                           {:paranoid_checks, boolean} |
                           {:verify_compactions, boolean} |
                           {:compression, boolean} |
                           {:use_bloomfilter, boolean | pos_integer} |
                           {:total_memory, pos_integer} |
                           {:total_leveldb_mem, pos_integer} |
                           {:total_leveldb_mem_percent, pos_integer} |
                           {:is_internal_db, boolean} |
                           {:limited_developer_mem, boolean} |
                           {:eleveldb_threads, pos_integer} |
                           {:fadvise_willneed, boolean} |
                           {:block_cache_threshold, pos_integer} |
                           {:delete_threshold, pos_integer} |
                           {:tiered_slow_level, pos_integer} |
                           {:tiered_fast_prefix, char_list} |
                           {:tiered_slow_prefix, char_list}]

  alias Exleveldb.Keys

  @moduledoc """
  Exleveldb is a thin wrapper around [Basho's eleveldb](https://github.com/basho/eleveldb).
  At the moment, Exleveldb exposes the functions defined in this module.
  """

  @doc """
  Takes a `name` string and an `opts` list and opens a new datastore in the 
  directory called `name`. If `name` does not exist already and no `opts` list
  was provided, `opts` will default to `[{:create_if_missing, :true}]`.
  
  Returns `{:ok, ""}` where what appears to be an empty binary is a reference to the opened
  datastore or, on error, `{:error, {:type, 'reason for error'}}`.
  """
  @spec open(db_location, open_options) :: {:ok, db_reference} | {:error, any}
  def open(name, opts \\ [create_if_missing: true]) do
    name
    |> :binary.bin_to_list
    |> :eleveldb.open opts
  end

  @doc """
  Takes a reference as returned by `open/2` and closes the specified datastore if open.

  Returns `:ok` or `{:error, {:type, 'reason for error'}}` on error.
  """
  def close(db_ref), do: :eleveldb.close(db_ref)

  @doc """
  Takes a reference as returned by `open/2`, a key, and an options list and
  retrieves a value in LevelDB by key. 

  Returns `{:ok, value}` when successful or `:not_found` on failed lookup.
  """
  def get(db_ref, key, opts \\ []), do: :eleveldb.get(db_ref, Keys.to_key(key), opts)

  @doc """
  Takes a reference as returned by `open/2`, a key and an options list and
  puts a single key-value pair into the datastore specified by the reference, `db_ref`.

  Returns `:ok` if successful or `{:error, reference {:type, action}}` on error.
  """
  def put(db_ref, key, val, opts \\ []) do
    :eleveldb.put(db_ref, Keys.to_key(key), val, opts)
  end

  @doc """
  Takes a reference as returned by `open/2`, a key and an options list and
  deletes the value associated with `key` in the datastore, `db_ref`.
  
  Returns `:ok` when successful or `{:error, reference, {:type, action}}` on error.
  """
  def delete(db_ref, key, opts \\ []), do: :eleveldb.delete(db_ref, key, opts)

  @doc """
  Takes a reference as returned by `open/2` and checks whether the datastore
  specified by `db_ref` is empty.
  
  Returns `true` if empty and `false` if not.
  """
  def is_empty?(db_ref), do: :eleveldb.is_empty(db_ref)

  @doc """
  Takes a reference as returned by `open/2` and an anonymous function,
  and maps over the key-value pairs in the datastore.

  Returns the results of applying the anonymous function to
  every key-value pair currently in the datastore.

  The argument to the anonymous function is `i` for the current item,
  i.e. key-value pair, in the list.
  """
  def map(db_ref, fun), do: fold(db_ref, fn(pair, acc) -> acc ++ [fun.(pair)] end, [])

  @doc """
  Takes a reference as returned by `open/2` and an anonymous function,
  and maps over the keys in the datastore.

  Returns the results of applying the anonymous function to
  every key in currently in the datastore.

  The argument to the anonymous function is `i` for the current item,
  i..e key, in the list.
  """
  def map_keys(db_ref, fun), do: fold_keys(db_ref, fn(key, acc) -> acc ++ [fun.(key)] end, [])

  @doc """
  Takes a reference as returned by `open/2`,
  and constructs a stream of all key-value pairs in the referenced datastore.
  When called with `:keys_only` as its second argument, only keys,
  not values will be emitted by the stream.

  Returns a stream with the datastore's key-value pairs as its enumerable.

  When calling `Enum.take/2` or similar on the resulting stream,
  specifying more entries than are in the referenced datastore
  will not yield an error but simply return a list of all pairs in the datastore.
  """
  def stream(db_ref) do
    Stream.resource(
    fn ->
      {:ok, iter} = iterator(db_ref)
      {:first, iter}
    end,
    fn {state, iter} ->
      case iterator_move(iter, state) do
        {:ok, k, v} -> {[{k,v}], {:next, iter}}
        _ -> {:halt, {state, iter}}
      end
    end,
    fn {_, iter} ->
      iterator_close(iter)
    end)
  end

  def stream(db_ref, :keys_only) do
    Stream.resource(
    fn ->
      {:ok, iter} = iterator(db_ref, [], :keys_only)
      {:first, iter}
    end,
    fn {state, iter} ->
      case iterator_move(iter, state) do
        {:ok, k} -> {[k], {:next, iter}}
        _ -> {:halt, {state, iter}}
      end
    end,
    fn {_, iter} ->
      iterator_close(iter)
    end)
  end

  @doc """
  Takes a reference as returned by `open/2`, an anonymous function,
  an accumulator, and an options list and folds over the key-value pairs
  in the datastore specified in `db_ref`.
  
  Returns the result of the last call to the anonymous function used in the fold.

  The two arguments passed to the anonymous function, `fun` are a tuple of the
  key value pair and `acc`.
  """
  def fold(db_ref, fun, acc, opts \\ []), do: :eleveldb.fold(db_ref, fun, acc, opts)

  @doc """
  Takes a reference as returned by `open/2`, an anonymous function,
  an accumulator, and an options list and folds over the keys
  of the open datastore specified by `db_ref`.

  Returns the result of the last call to the anonymous function used in the fold.

  The two arguments passed to the anonymous function, `fun` are a key and `acc`.
  """
  def fold_keys(db_ref, fun, acc, opts \\ []), do: :eleveldb.fold_keys(db_ref, fun, acc, opts)

  @doc """
  Performs a batch write to the datastore, either deleting or putting key-value pairs.

  Takes a reference to an open datastore, a list of tuples (containing atoms
  for operations and strings for keys and values)
  designating operations (delete or put) to be done, and a list of options.

  Returns `:ok` on success and `{:error, reference, {:type, reason}}` on error.
  """
  def write(db_ref, updates, opts \\ []), do: :eleveldb.write(db_ref, updates, opts)

  @doc """
  Takes a reference to a data store, then creates and returns `{:ok, ""}` where the 
  seemingly empty binary is a reference to the iterator. As with `db_ref`, the iterator
  reference is an opaque type and as such appears to be an empty binary because it's
  internal to the eleveldb module.

  If the `:keys_only` atom is given after opts, the iterator will only traverse keys.
  """
  def iterator(db_ref, opts \\ []), do: :eleveldb.iterator(db_ref, opts)
  def iterator(db_ref, opts, :keys_only), do: :eleveldb.iterator(db_ref, opts, :keys_only)

  @doc """
  Takes an iterator reference and an action and returns the corresponding key-value pair.

  An action can either be `:first`, `:last`, `:next`, `:prev`, `:prefetch`, or a binary
  representing the key of the pair you want to fetch.
  """
  def iterator_move(iter_ref, action), do: :eleveldb.iterator_move(iter_ref, action)

  @doc """
  Takes an iterator reference, closes the iterator, and returns `:ok`.
  """
  def iterator_close(iter_ref), do: :eleveldb.iterator_close(iter_ref)

  @doc """
  Destroy a database, which implies the deletion of the database folder. Takes a string with the path to the database and a list of options. 
  Returns `:ok` on success and `{:error, any}` on error. 
  """
  def destroy(path, opts \\ []) do
    path
    |> :binary.bin_to_list
    |> :eleveldb.destroy opts
  end
  @doc """
  Takes the path to the leveldb database and a list of options. The standard recomended option is the empty list `[]`.
  Before calling `repair/2`, close the connection to the database with `close/1`.
  Returns `:ok` on success and `{:type, 'reason for error'}` on error.
  """
  def repair(path,opts \\ []) do 	
    path
    |> :binary.bin_to_list
    |> :eleveldb.repair opts
  end
end
