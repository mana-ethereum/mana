Exleveldb
=========

This is an Elixir module wrapping the functions exposed by the Erlang module, [eleveldb](https://github.com/basho/eleveldb).

It may include a few extra convenience functions in the future, for more idiomatic Elixir, but at this point, the goal is just to wrap eleveldb's functions and document it well enough for it to be usable right away.

As the module is expanded, the docs will be copied to this file for Github-friendliness, but for now, please refer to lib/exleveldb for the heredocs.

*Note:* Because eleveldb is not a hex package, you may need to specify it as a separate dependency in `mix.exs` when using Exleveldb in other projects.
