# ABI

The [Application Binary Interface](https://solidity.readthedocs.io/en/develop/abi-spec.html) (ABI) application encodes and decodes  data for use in Solidity-created smart contracts. Data is encoded according to its [type](#Support), and contains the parameters and contents necessary to pass into an Ethereum transaction.

## Usage

### Encoding

To encode a function call, pass the ABI spec and data to `ABI.encode/1`.

```elixir
iex> ABI.encode("baz(uint,address)", [50, <<1::160>> |> :binary.decode_unsigned])
<<162, 145, 173, 214, 0, 0, 0, 0, 0, 0, 0, 0, ...>
```

Then, you can construct an Ethereum transaction with that data, e.g.

```elixir
# Blockchain comes from `Mana-Ethereum.Blockchain`, see below.
iex> %Blockchain.Transaction{
...> # ...
...> data: <<162, 145, 173, 214, 0, 0, 0, 0, 0, 0, 0, 0, ...>
...> }
```

That transaction can then be sent via JSON-RPC or DevP2P to execute the given function.

### Decoding

Decode is the opposite of encode, and does not require the function selector (the first 4 bytes of the Keccak hash at the beginning of the call data i.e. 0xcdcd77c0).

```elixir
iex> ABI.decode("baz(uint,address)", "000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000320000000000000000000000000000000000000000000000000000000000000001" |> Base.decode16!(case: :lower))
[50, <<1::160>> |> :binary.decode_unsigned]
```

## Support

Currently support for the following types:

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
* [Mana-Ethereum Blockchain](https://github.com/poanetwork/mana/tree/master/apps/blockchain)

# Contributing

See the [CONTRIBUTING](https://github.com/poanetwork/mana/blob/master/CONTRIBUTING.md) document for contribution, testing and pull request protocol.
