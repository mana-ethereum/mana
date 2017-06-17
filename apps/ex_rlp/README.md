# ExRLP [![CircleCI](https://circleci.com/gh/exthereum/ex_rlp.svg?style=svg)](https://circleci.com/gh/exthereum/ex_rlp)

Elixir implementation of Ethereum's RLP (Recursive Length Prefix) encoding

The encoding's specification can be found in [the yellow paper](http://yellowpaper.io/) or in the [ethereum wiki](https://github.com/ethereum/wiki/wiki/RLP)

## Installation

The easiest way to add ExRLP to your project is by [using Mix](http://elixir-lang.org/getting-started/mix-otp/introduction-to-mix.html).

Add `:ex_rlp` as a dependency to your project's `mix.exs`:

```elixir
defp deps do
  [
    {:ex_rlp, "~> 0.1.0"}
  ]
end
```

And run:

    $ mix deps.get

## Basic Usage

Use ExRLP.encode/1 method to encode an item to RLP representation. An item can be nonnegative integer, binary or list. List can contain integers, binaries or lists.

```elixir

  ## Examples
  
  iex(1)> "dog" |> ExRLP.encode
  "83646f67"
  
  iex(2)> 1000 |> ExRLP.encode
  "8203e8"
  
  iex(3)> [ [ [], [] ], [] ] |> ExRLP.encode
  "c4c2c0c0c0"
```

Use ExRLP.decode/1 method to decode a rlp encoded data. All items except lists are decoded as binaries so additional deserialization is needed if initially an item of another type was encoded.


```elixir

  ## Examples
  
  iex(1)> "83646f67" |> ExRLP.decode
  "dog"
  
  iex(2)> "8203e8" |> ExRLP.decode |> :binary.decode_unsigned
  1000
  
  iex(3)> "c4c2c0c0c0" |> ExRLP.decode
  [[[], []], []]
```

More example can be found in test files.

## Contributing

1. [Fork it!](https://github.com/exthereum/ex_rlp/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Author

Ayrat Badykov (@ayrat555)

## License

Rock is released under the MIT License. See the LICENSE file for further details.

