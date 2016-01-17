Exleveldb
=========

**Warning:** Note that the master branch of `eleveldb` is not yet compatible with OTP18 due to a dependency. If you're not planning on running your Elixir project on OTP17.x, watch this space for whenever that's fixed. Sorry for the inconvenience.

[![Hex Version](http://img.shields.io/hexpm/v/exleveldb.svg?style=flat-square)](https://hex.pm/packages/exleveldb)

This is an Elixir module wrapping the functions exposed by the Erlang module, [eleveldb](https://github.com/basho/eleveldb).

*Note:* Because eleveldb is not a hex package and I haven't found a way to automate this yet, you will need to add eleveldb in your `mix.exs` as well, when requiring this wrapper, so that your `deps` looks like this (in addition to other deps you might have):

```elixir
defp deps do
  [{:exleveldb, "~> 0.6"},
   {:eleveldb, github: "basho/eleveldb", tag: "2.1.0"}]
end
```

*Because this is a bit silly and verbose, I'd be happy to get PRs on ways to automate this away.*

## Usage

Also available at [hexdocs.pm/exleveldb](http://hexdocs.pm/exleveldb/)

### open/2
Opens a new datastore in the directory called `name`. If `name` does not exist already and no `opts` list was provided, `opts` will default to `[{:create_if_missing, :true}]`.

Returns `{:ok, ""}` where the empty string is a reference to the opened datastore or, on error, `{:error, {:type, 'reason for error'}}`.

The reference to the database appears to be an empty binary but isn't. This is because `db_ref` is defined as an opaque type in eleveldb.

The best way to use the reference is to pattern match on the pair returned by `open/2` and keep the value for use with functions that take a `db_ref`.

### close/1
Takes a reference as returned by `open/2` and closes the specified datastore if open.

Returns `:ok` or `{:error, {:type, 'reason for error'}}` on error.

### get/3
Retrieves a value in LevelDB by key. Takes a reference as returned by `open/2`, a key, and an options list.

Returns `{:ok, value}` when successful or `:not_found` on failed lookup.

### put/4
Puts a single key-value pair into the datastore specified by the reference, `db_ref`.

Returns `:ok` if successful or `{:error, reference {:type, action}}` on error.

### delete/3
Deletes the value associated with `key` in the datastore, `db_ref`.

Returns `:ok` when successful or `{:error, reference, {:type, action}}` on error.

### is\_empty?/1
Checks whether the datastore specified by `db_ref` is empty and returns a boolean.

### fold/4
Folds over the key-value pairs in the datastore specified in `db_ref`.

Returns the result of the last call to the anonymous function used in the fold.

The two arguments passed to the anonymous function, `fun` are a tuple of the key value pair and `acc`.

### fold\_keys/4
Folds over the keys of the open datastore specified by `db_ref`.

Returns the result of the last call to the anonymous function used in the fold.

The two arguments passed to the anonymous function, `fun` are a key and `acc`.

### map/2
Takes a reference as returned by `open/2` and an anonymous function,
and maps over the key-value pairs in the datastore.

Returns the results of applying the anonymous function to
every key-value pair currently in the datastore.

The argument to the anonymous function is `i` for the current item,
i.e. key-value pair, in the list.

### map_keys/2
Takes a reference as returned by `open/2` and an anonymous function,
and maps over the keys in the datastore.

Returns the results of applying the anonymous function to
every key in currently in the datastore.

The argument to the anonymous function is `i` for the current item,
i..e key, in the list.

### stream/1
Takes a reference as returned by `open/2`,
and constructs a stream of all key-value pairs in the referenced datastore.

Returns a `Stream` struct with the datastore's key-value pairs as its enumerable.

When calling `Enum.take/2` or similar on the resulting stream,
specifying more entries than are in the referenced datastore
will not yield an error but simply return a list of all pairs in the datastore.

### stream_keys/1
Takes a reference as returned by `open/2`,
and constructs a stream of all the keys in the referenced datastore.

Returns a `Stream` struct with the datastore's keys as its enum field.

When calling `Enum.take/2` or similar on the resulting stream,
specifying more entries than are in the referenced datastore
will not yield an error but simply return a list of all pairs in the datastore.

### destroy/2
Remove a database, which implies that the database folder is deleted. Before calling `destroy/2` the database has to be closed with `close/1`. Returns `:ok` on success and `{:type, 'reason for error'}` on error.

### repair/2
This function takes the path to the leveldb database and a list of options. The standard recomended option is the empty list `[]`.
Before calling `repair/2`, close the connection to the database with `close/1`.
Returns `:ok` on success and `{:type, 'reason for error'}` on error.

### write/3
Performs a batch write to the datastore, either deleting or putting key-value pairs.

Takes a reference to an open datastore, a list of tuples (containing atoms for operations and strings for keys and values) designating operations (delete or put) to be done, and a list of options.

Returns `:ok` on success and `{:error, reference, {:type, reason}}` on error.
