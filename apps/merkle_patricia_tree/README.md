# MerklePatriciaTree [![CircleCI](https://circleci.com/gh/exthereum/merkle_patricia_tree.svg?style=svg)](https://circleci.com/gh/exthereum/merkle_patricia_tree)

Elixir implementation of Ethereum's Merkle Patricia Tries.

The encoding's specification can be found in [the yellow paper](http://yellowpaper.io/) or in the [ethereum wiki](https://github.com/ethereum/wiki/wiki/RLP) under Appendix D.

The modified patricia merkle trie allows arbitrary storage of key, value pairs with the benefits of a merkle trie in O(n*log(n)) time for insert, lookup and delete.

[This diagram](https://i.stack.imgur.com/YZGxe.png) is also very helpful in understanding these tries.

## Installation

The easiest way to add MerklePatriciaTree to your project is by [using Mix](http://elixir-lang.org/getting-started/mix-otp/introduction-to-mix.html).

Add `:merkle_patricia_tree` as a dependency to your project's `mix.exs`:

```elixir
defp deps do
  [
    {:merkle_patricia_tree, "~> 0.2.4"}
  ]
end
```

And run:

    $ mix deps.get

## Basic Usage

Use the `MerklePatriciaTree` module to create and build merkle patricia tries. You will be required to choose
a storage database, and we currently support `:ets` and `:leveldb`. The follow example illustrates how to
create an update a trie.

```elixir
  ## Examples

    iex> trie =
    ...>    MerklePatriciaTree.Test.random_ets_db()
    ...>    |> MerklePatriciaTree.Trie.new()
    ...>    |> MerklePatriciaTree.Trie.update(<<0x01::4, 0x02::4>>, "wee")
    ...>    |> MerklePatriciaTree.Trie.update(<<0x01::4, 0x02::4, 0x03::4>>, "cool")
    iex> trie_2 = MerklePatriciaTree.Trie.update(trie, <<0x01::4, 0x02::4, 0x03::4>>, "cooler")
    iex> MerklePatriciaTree.Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4>>) 
    "cool"
    iex> MerklePatriciaTree.Trie.get(trie_2, <<0x01::4>>)
    nil
    iex> MerklePatriciaTree.Trie.get(trie_2, <<0x01::4, 0x02::4>>)
    "wee"
    iex> MerklePatriciaTree.Trie.get(trie_2, <<0x01::4, 0x02::4, 0x03::4>>)
    "cooler"
    iex> MerklePatriciaTree.Trie.get(trie_2, <<0x01::4, 0x02::4, 0x03::4, 0x04::4>>)
    nil
```

## Contributing

1. [Fork it!](https://github.com/exthereum/merkle_patricia_trie/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Author

Geoffrey Hayes (@hayesgm)
Ayrat Badykov (@ayrat555)

## License

HexPrefix is released under the MIT License. See the LICENSE file for further details.
