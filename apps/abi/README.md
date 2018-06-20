# ABI

The [Application Binary Interface](https://solidity.readthedocs.io/en/develop/abi-spec.html) (ABI) of Solidity describes how to transform binary data to types which the Solidity programming language understands. For instance, if we want to call a function `bark(uint32,bool)` on a Solidity-created contract `contract Dog`, what `data` parameter do we pass into our Ethereum transaction? This project allows us to encode such function calls.

## Usage

### Encoding

To encode a function call, pass the ABI spec and the data to pass in to `ABI.encode/1`.

```elixir
iex> ABI.encode("baz(uint,address)", [50, <<1::160>> |> :binary.decode_unsigned])
<<162, 145, 173, 214, 0, 0, 0, 0, 0, 0, 0, 0, ...>
```

Then, you can construct an Ethereum transaction with that data, e.g.

```elixir
iex> %Blockchain.Transaction{
...> # ...
...> data: <<162, 145, 173, 214, 0, 0, 0, 0, 0, 0, 0, 0, ...>
...> }
```

That transaction can then be sent via JSON-RPC or DevP2P to execute the given function.

### Decoding

Decode is generally the opposite of encoding, though we generally leave off the function signature from the start of the data. E.g. from above:

```elixir
iex> ABI.decode("baz(uint,address)", "000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000320000000000000000000000000000000000000000000000000000000000000001" |> Base.decode16!(case: :lower))
[50, <<1::160>> |> :binary.decode_unsigned]
```

## Support

Currently supports:

  * [X] `uint<M>`
  * [X] `int<M>`
  * [X] `address`
  * [X] `uint`
  * [X] `bool`
  * [ ] `fixed<M>x<N>`
  * [ ] `ufixed<M>x<N>`
  * [ ] `fixed`
  * [ ] `bytes<M>`
  * [ ] `function`
  * [X] `<type>[M]`
  * [X] `bytes`
  * [X] `string`
  * [X] `<type>[]`
  * [X] `(T1,T2,...,Tn)` (* currently ABI parsing doesn't parse tuples with multiple elements)

# Docs

* [Solidity ABI](https://solidity.readthedocs.io/en/develop/abi-spec.html)
* [Solidity Docs](https://solidity.readthedocs.io/)
* [Solidity Grammar](https://github.com/ethereum/solidity/blob/develop/docs/grammar.txt)
* [Mana blockchain](https://github.com/poanetwork/mana/apps/blockchain)

# Collaboration

This ABI library is licensed under the MIT license. Feel free to submit issues, pull requests or fork the code as you wish.
