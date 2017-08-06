# Exthereum Blockchain [![CircleCI](https://circleci.com/gh/exthereum/blockchain.svg?style=svg)](https://circleci.com/gh/exthereum/blockchain)

Elixir implementation of Ethereum's Blockchain. This includes functionality to build and verify a chain of Ethereum blocks that may be advertised from any peer. We complete the resultant state of the blocktree and form a canonical blockchain based on difficulty.

Exthereum's blocks are specified in a variety of sections throughout [the yellow paper](http://yellowpaper.io/), but it's best to start looking under Section 4.4.

## Installation

```bash
export "CFLAGS=-I/usr/local/include -L/usr/local/lib"
mix deps.compile libsecp256k1
mix compile
```

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `blockchain` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:blockchain, "~> 0.1.2"}]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/blockchain](https://hexdocs.pm/blockchain).

## Contributing

1. [Fork it!](https://github.com/exthereum/blockchain/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Author

Geoffrey Hayes (@hayesgm)
Ayrat Badykov (@ayrat555)

## License

Blockchain is released under the MIT License. See the LICENSE file for further details.
