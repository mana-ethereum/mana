# Mana blockchain

Elixir implementation of Ethereum's blockchain.
This includes functionality to build and verify a chain of Ethereum blocks that may be advertised from any peer.
We complete the resultant state of the blocktree and form a canonical blockchain based on difficulty.

Mana blocks are specified in a variety of sections throughout [the yellow paper](https://ethereum.github.io/yellowpaper/paper.pdf),
but it's best to start looking under Section 4.3.

## Installation

```bash
export "CFLAGS=-I/usr/local/include -L/usr/local/lib"
cd deps/libsecp256k1 && rebar compile
mix compile
```

## Debugging

To debug a given run of the blockchain, you can set breakpoints on contract addresses by
setting the `BREAKPOINT` environment variable and specifying a contract address to break on. E.g.

```bash
BREAKPOINT=bc1ffc1620da1468624a596cb841d35e6b2f1fb6 iex -S mix

...

00:04:18.739 [warn]  Debugger has been enabled. Set breakpoint #1 on contract address 0xbc1ffc1620da1468624a596cb841d35e6b2f1fb6.

...

-- Breakpoint #1 triggered with conditions contract address 0xbc1ffc1620da1468624a596cb841d35e6b2f1fb6 (start) --

gas: 277888 | pc: 0 | memory: 0 | words: 0 | # stack: 0

----> [ 0] push2
      [ 1] 0
      [ 2] 4
      [ 3] dup1
      [ 4] push2
      [ 5] 0
      [ 6] 14
      [ 7] push1
      [ 8] 0
      [ 9] codecopy

Enter a debug command or type `h` for help.

>>
```

## Contributing

1. [Fork it!](https://github.com/poanetwork/mana/blockchain/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Author

Geoffrey Hayes (@hayesgm)
Ayrat Badykov (@ayrat555)
Mason Fischer (@masonforest)
Vasiliy Yorkin (@vyorkin)

## License

Mana blockchain is released under the MIT License.
Feel free to submit issues, pull requests or fork the code as you wish.
See the LICENSE file for further details.
