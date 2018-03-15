# ExRLP [![CircleCI](https://circleci.com/gh/exthereum/ex_rlp.svg?style=svg)](https://circleci.com/gh/exthereum/ex_rlp)

Elixir implementation of Ethereum's RLP (Recursive Length Prefix) encoding

The encoding's specification can be found in [the yellow paper](http://yellowpaper.io/) or in the [ethereum wiki](https://github.com/ethereum/wiki/wiki/RLP)

## Installation

The easiest way to add ExRLP to your project is by [using Mix](http://elixir-lang.org/getting-started/mix-otp/introduction-to-mix.html).

Add `:ex_rlp` as a dependency to your project's `mix.exs`:

```elixir
defp deps do
  [
    {:ex_rlp, "~> 0.2.1"}
  ]
end
```

And run:

    $ mix deps.get

## Basic Usage

Use ExRLP.encode/1 method to encode an item to RLP representation. An item can be nonnegative integer, binary or list. List can contain integers, binaries or lists.

```elixir
  ## Examples

      iex(1)> "dog" |> ExRLP.encode(encoding: :hex)
      "83646f67"

      iex(2)> "dog" |> ExRLP.encode(encoding: :binary)
      <<0x83, 0x64, 0x6f, 0x67>>

      iex(3)> 1000 |> ExRLP.encode(encoding: :hex)
      "8203e8"

      # Default encoding is binary
      iex(3)> 1000 |> ExRLP.encode
      <<0x82, 0x03, 0xe8>>

      iex(4)> [ [ [], [] ], [] ] |> ExRLP.encode(encoding: :hex)
      "c4c2c0c0c0"
```

Use ExRLP.decode/1 method to decode a rlp encoded data. All items except lists are decoded as binaries so additional deserialization is needed if initially an item of another type was encoded.


```elixir

  ## Examples

      iex(1)> "83646f67" |> ExRLP.decode(:binary, encoding: :hex)
      "dog"

      iex(2)> "8203e8" |> ExRLP.decode(:binary, encoding: :hex) |> :binary.decode_unsigned
      1000

      iex(3)> "c4c2c0c0c0" |> ExRLP.decode(:binary, encoding: :hex)
      [[[], []], []]
```

More examples can be found in test files.

## Protocols

You can define protocols for encoding/decoding custom data types.

Custom protocols for Map have already been implemented in ExRLP:

```elixir

defimpl ExRLP.Encoder, for: Map do
  alias ExRLP.Encode

  def encode(map, _) do
    map
    |> Map.values
    |> Encode.encode
  end
end

defimpl ExRLP.Decoder, for: BitString do
  alias ExRLP.Decode

  def decode(value, :map, options) do
    keys =
      options
      |> Keyword.fetch!(:keys)
      |> Enum.sort

    value
    |> Decode.decode
    |> Enum.with_index
    |> Enum.reduce(%{}, fn({value, index}, acc) ->
      key = keys |> Enum.at(index)

      acc |> Map.put(key, value)
    end)

    ...
  end
end
```
So now it's possible to encode/decode maps:
```elixir
iex(1)> %{name: "Vitalik", surname: "Buterin"} |> ExRLP.encode(encoding: :hex)
"d087566974616c696b874275746572696e"

iex(2)> "d087566974616c696b874275746572696e" |> ExRLP.decode(:map, keys: [:surname, :name], encoding: :hex)
%{name: "Vitalik", surname: "Buterin"}
```

## Contributing

1. [Fork it!](https://github.com/exthereum/ex_rlp/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Author

Ayrat Badykov (@ayrat555)

## License

ExRLP is released under the MIT License. See the LICENSE file for further details.
