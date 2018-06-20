# MerklePatriciaTree

Elixir implementation of Ethereum's Merkle Patricia Trie.
The encoding's specification can be found in [the yellow paper](http://yellowpaper.io/) or in the [ethereum wiki](https://github.com/ethereum/wiki/wiki/RLP) under Appendix D.
The modified merkle patricia trie allows arbitrary storage of key, value pairs with the benefits of a merkle trie in `O(n*log(n))` time for insert, lookup and delete.

[This diagram](https://i.stack.imgur.com/YZGxe.png) is also very helpful in understanding these tries.

## Basic Usage

Use the `MerklePatriciaTree` module to create and build merkle patricia tries. You will be required to choose
a storage database, and we currently support `:ets` and `:rocksdb`.
The follow example illustrates how to create an update a trie.

```elixir
  ## Examples

    iex> trie =
    ...>    MerklePatriciaTree.Test.random_ets_db()
    ...>    |> MerklePatriciaTree.Trie.new()
    ...>    |> MerklePatriciaTree.Trie.update(<<0x01::4, 0x02::4>>, "wee")
    ...>    |> MerklePatriciaTree.Trie.update(<<0x01::4, 0x02::4, 0x03::4>>, "cool")
    iex> trie_2 = MerklePatriciaTree.Trie.update(trie, <<0x01::4, 0x02::4, 0x03::4>>, "cooler")
    iex> MerklePatriciaTree.Trie.get(trie_2, <<0x01::4, 0x02::4, 0x03::4>>)
    "cooler"
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

1. [Fork it!](https://github.com/mana/apps/merkle_patricia_trie/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Author

Geoffrey Hayes (@hayesgm)
Ayrat Badykov (@ayrat555)

## License

MerklePatriciaTree is released under the MIT License. See the LICENSE file for further details.
