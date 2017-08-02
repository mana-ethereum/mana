# HexPrefix [![CircleCI](https://circleci.com/gh/exthereum/hex_prefix.svg?style=svg)](https://circleci.com/gh/exthereum/hex_prefix)

Elixir implementation of Ethereum's Hex Prefix encoding

The encoding's specification can be found in [the yellow paper](http://yellowpaper.io/) or in the [ethereum wiki](https://github.com/ethereum/wiki/wiki/RLP) under Appendix C.

## Installation

The easiest way to add HexPrefix to your project is by [using Mix](http://elixir-lang.org/getting-started/mix-otp/introduction-to-mix.html).

Add `:hex_prefix` as a dependency to your project's `mix.exs`:

```elixir
defp deps do
  [
    {:hex_prefix, "~> 0.1.0"}
  ]
end
```

And run:

    $ mix deps.get

## Basic Usage

Use `HexPrefix.encode/1` to encode a list of nibbles using hex-prefix notation.

```elixir
  ## Examples

    iex> HexPrefix.encode({[0xa, 0xb, 0xc, 0xd], false})
    <<0, 171, 205>>

    iex> HexPrefix.encode({[0xa, 0xb, 0xc, 0xd], true})
    <<32, 171, 205>>

    iex> HexPrefix.encode({[0x09, 0xa, 0xb, 0xc, 0xd], false})
    <<25, 171, 205>>
```

Use `HexPrefix.decode/1` to decode a binary encoded via hex-prefix notation.

```elixir
  ## Examples

    iex> HexPrefix.decode(<<0, 171, 205>>)
    {[0xa, 0xb, 0xc, 0xd], false}

    iex> HexPrefix.decode(<<32, 171, 205>>)
    {[0xa, 0xb, 0xc, 0xd], true}

    iex> HexPrefix.decode(<<25, 171, 205>>)
    {[0x09, 0xa, 0xb, 0xc, 0xd], false}
```

## Contributing

1. [Fork it!](https://github.com/exthereum/hex_prefix/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Author

Geoffrey Hayes (@hayesgm)
Ayrat Badykov (@ayrat555)

## License

HexPrefix is released under the MIT License. See the LICENSE file for further details.
