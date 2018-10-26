# MerklePatriciaTree

Elixir implementation of Ethereum's Merkle Patricia Tries.

The encoding's specification can be found in [the yellow paper](https://github.com/ethereum/yellowpaper) or in the [ethereum wiki](https://github.com/ethereum/wiki/wiki/RLP) under Appendix D.

The modified patricia merkle trie allows arbitrary storage of key, value pairs with the benefits of a merkle trie in O(n*log(n)) time for insert, lookup and delete.

[This diagram](https://i.stack.imgur.com/YZGxe.png) is also very helpful in understanding these tries.

## Basic Usage

Use the `MerklePatriciaTree` module to create and build merkle patricia tries. You will be required to choose
a storage database, and we currently support `:ets` and `:rocksdb`. The follow example illustrates how to
create an update a trie.

```elixir
  ## Examples

    iex> trie =
    ...>    MerklePatriciaTree.Test.random_ets_db()
    ...>    |> MerklePatriciaTree.Trie.new()
    ...>    |> MerklePatriciaTree.Trie.update_key(<<0x01::4, 0x02::4>>, "wee")
    ...>    |> MerklePatriciaTree.Trie.update_key(<<0x01::4, 0x02::4, 0x03::4>>, "cool")
    iex> trie_2 = MerklePatriciaTree.Trie.update_key(trie, <<0x01::4, 0x02::4, 0x03::4>>, "cooler")
    iex> MerklePatriciaTree.Trie.get_key(trie_2, <<0x01::4, 0x02::4, 0x03::4>>)
    "cooler"
    iex> MerklePatriciaTree.Trie.get_key(trie_2, <<0x01::4>>)
    nil
    iex> MerklePatriciaTree.Trie.get_key(trie_2, <<0x01::4, 0x02::4>>)
    "wee"
    iex> MerklePatriciaTree.Trie.get_key(trie_2, <<0x01::4, 0x02::4, 0x03::4>>)
    "cooler"
    iex> MerklePatriciaTree.Trie.get_key(trie_2, <<0x01::4, 0x02::4, 0x03::4, 0x04::4>>)
    nil
```

## Installation

Installation is handled through the bin/setup procedure in the [Mana-Ethereum README](../../README.md).


## Contributing

See the [CONTRIBUTING](../../CONTRIBUTING.md) document for contribution, testing and pull request protocol.
