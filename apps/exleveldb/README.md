Exleveldb
=========

This is an Elixir module wrapping the functions exposed by the Erlang module, [eleveldb](https://github.com/basho/eleveldb).

It may include a few extra convenience functions in the future, for more idiomatic Elixir, but at this point, the goal is just to wrap eleveldb's functions and document it well enough for it to be usable right away.

*Note:* Because eleveldb is not a hex package, you will need to run `mix do deps.get, deps.compile` in your project when using this wrapper.

## Usage

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

## write/3
Performs a batch write to the datastore, either deleting or putting key-value pairs.

Takes a reference to an open datastore, a list of tuples (containing atoms for operations and strings for keys and values) designating operations (delete or put) to be done, and a list of options.

Returns `:ok` on success and `{:error, reference, {:type, reason}}` on error.
