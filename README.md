# Mana-Ethereum

[![CircleCI](https://circleci.com/gh/mana-ethereum/mana.svg?style=svg)](https://circleci.com/gh/mana-ethereum/mana) [![Waffle.io - Columns and their card count](https://badge.waffle.io/mana-ethereum/mana.svg?columns=all)](https://waffle.io/mana-ethereum/mana)[![Gitter chat](https://badges.gitter.im/mana-ethereum/mana.png)](https://gitter.im/mana-ethereum/mana)

Mana-Ethereum is an open-source Ethereum blockchain client built using [Elixir](https://elixir-lang.org/). Elixir runs on the Erlang Virtual Machine, which is used for distributed systems and offers massive scalability and high visibility. These properties make Elixir a perfect candidate for blockchain network development.

In the current Ethereum ecosystem, a majority of active nodes on the network are Geth or Parity nodes. Mana-Ethereum provides an additional open-source alternative. Our aim is to create an open, well-documented implementation that closely matches the protocols described in the [Ethereum yellow paper](https://ethereum.github.io/yellowpaper/paper.pdf).

Mana-Ethereum is currently in development. See the [Project Status](#project-status) for more information.

# Dependencies

- Elixir ~> 1.7.3
- Rust ~> 1.26.0 (as a dependency of [Rox](https://github.com/urbint/rox))

# Installation

- Clone repo with submodules (to access the Ethereum common tests)

```
git clone --recurse-submodules https://github.com/mana-ethereum/mana.git
```

- Go to the mana subdirectory `cd mana`

- Run `bin/setup`

# Running a node

Currently, peer-to-peer communication is incomplete, but if you would like
to partially sync blocks, you can use an experimental script to [sync with
Infura](https://github.com/mana-ethereum/mana/blob/master/apps/blockchain/scripts/sync_with_infura.ex). This script downloads blocks from Infura, runs the transactions inside them then verifies the block.

## Sync From RPC Client

To sync a chain from an RPC Client (e.g. Infura) or a local client,
run the following command:

```bash
mix sync --chain ropsten
```

You can sign up for an [Infura API key here](https://infura.io/register). This will ensure your requests are not throttled.

```bash
mix sync --chain ropsten --provider-url https://ropsten.infura.io/v3/<api_key>
```

Alternatively, you can sync via IPC to a local node (like Parity or Geth running locally):

```bash
mix sync --chain ropsten --provider-url ipc://~/Library/Application\ Support/io.parity.ethereum/jsonrpc.ipc
```

You can begin syncing, you will see a timestamp and a running list of verified blocks.

### Known Sync Issues

- When running the script mainnet fails due to an as of yet undiagnoised issue
  (see [this issue]). The current highest block we've reached is [1660868].
- Ropsten fails on block [295311] with `receipts_root_mismatch`,
  `gas_used_mismatch` and `state_root_mismatch` errors.

[this issue]: https://github.com/poanetwork/mana/issues/492
[1660868]: https://etherscan.io/txs?block=1660868
[295311]: https://ropsten.etherscan.io/txs?block=295311

### Helpful debugging tools

When trying to debug why the `sync_with_infura` script is failing to verify a
block, we have found [etherscan] to be very helpful. Take block `177610` for
example,

We can look at the [block information], and dive into the [transaction
information]. From that page, the "Tools & Utilities" dropdown provides very
helpful debugging tools. Two of the most valuable are [Geth DebugTrace] and
[Remix Debugger],

- `Geth DebugTrace` allows us to compare each operation and its gas consumption
  against our implementation.

- `Remix Debugger` allows us to compare the stack against our implementation's
  stack for each cycle of the virtual machine.

NOTE: for the `Remix Debugger`, you may want to add the block number at the top
before pressing the play button.

To log the operation, gas consumption, and stack in our application, please see
the EVM README's [example setup].

[etherscan]: https://etherscan.io/
[block information]: https://etherscan.io/block/177610
[transaction information]: https://etherscan.io/tx/0x7f79a541615694029d845e31f2f362484679c1b9a3fd8588822a33a0e13383f4
[geth debugtrace]: https://etherscan.io/vmtrace?txhash=0x7f79a541615694029d845e31f2f362484679c1b9a3fd8588822a33a0e13383f4
[remix debugger]: http://etherscan.io/remix?txhash=0x7f79a541615694029d845e31f2f362484679c1b9a3fd8588822a33a0e13383f4
[example setup]: https://github.com/poanetwork/mana/tree/master/apps/evm#example-setup

# Testing

Run:

```
mix test --exclude network
```

Tests tagged with network integrate with other nodes and cannot run unless another node is running in parallel. Use the `--exclude network` flag to exclude these tests.

If you want to only run [Ethereum common
tests](https://github.com/ethereum/tests), we currently have:

```
# Ethereum Virtual Machine tests
cd apps/evm && mix test test/evm_test.exs

# Ethereum Blockchain tests
cd apps/blockchain && mix test test/blockchain_test.exs

# Ethereum General State tests
cd apps/blockchain && mix test test/blockchain/state_test.exs

# Ethereum Transaction tests
cd apps/blockchain && mix test test/blockchain/transaction_test.exs
```

## Test Status

Ethereum common tests are created for all clients to test against. We plan to progress through supported hard fork test protocols, and are currently working on the Homestead tests. See the [common test documentation](http://ethereum-tests.readthedocs.io/en/latest/index.html) for more information.

[VMTests](https://github.com/ethereum/tests/tree/develop/VMTests/vmTests) = 100% passing

| Hardfork          | [BlockchainTests] passing | [GeneralStateTests] passing | Complete? |
| ----------------- | ------------------------- | --------------------------- | --------- |
| Frontier          | 100% (1320/1320)          | 100% (1033/1033)            | ✓         |
| Homestead         | 100% (2203/2203)          | 100% (2061/2061)            | ✓         |
| HomesteadToDaoAt5 | 100% (4/4)                | N/A                         | ✓         |
| TangerineWhistle  | 100% (1262/1262)          | 100% (1112/1112)            | ✓         |
| SpuriousDragon    | 100% (1193/1193)          | 100% (1172/1172)            | ✓         |
| Byzantium         | 100% (4945/4945)          | 100% (4790/4790)            | ✓         |
| Constantinople    | 99.9% (5363/5369)         | 99.9% (5325/5331)           |           |

View the community [Constantinople Project Tracker](https://github.com/ethereum/pm/issues/53).

[blockchaintests]: https://github.com/ethereum/tests/tree/develop/BlockchainTests
[generalstatetests]: https://github.com/ethereum/tests/tree/develop/GeneralStateTests

## Updating the Common test

The Ethereum common tests are in a submodule. To update you'll want to:

```bash
% cd ethereum_common_tests
% git checkout develop
% git pull
```

# Project Status

| Functionality                                                                       | Status                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| ----------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Encoding and Hashing                                                                | The [RLP](https://hex.pm/packages/ex_rlp) encoding protocol and the [Merkle Patricia Tree](https://github.com/poanetwork/mana/tree/master/apps/merkle_patricia_tree) data structure are fully implemented.                                                                                                                                                                                                                                                                                                                                                                                                       |
| [Ethereum Virtual Machine](https://github.com/poanetwork/mana/tree/master/apps/evm) | Our EVM currently passes 100% of the common [VM tests](https://github.com/ethereum/tests/tree/develop/VMTests). We are still discovering subtle differences in our implementation such as the [“vanishing Ether” issue](https://github.com/poanetwork/mana/commit/aa3056efe341dd548a750c6f5b4c8962ccef2518). This component is for the most part complete.                                                                                                                                                                                                                                                       |
| Peer to Peer Networking                                                             | Currently we can connect to one of the Ethereum bootnodes, get a list of peers, and add them to a list of known peers. We have fully implemented the modified [kademlia DHT](https://github.com/poanetwork/mana/tree/master/apps/ex_wire/lib/ex_wire/kademlia). <br /><br />We can also successfully perform the encrypted handshake with peer nodes and derive secrets to frame the rest of the messages. We have not yet implemented the ability to send [multi-frame packets](https://github.com/ethereum/devp2p/blob/master/rlpx.md#framing). See Issue [#97](https://github.com/poanetwork/mana/issues/97). |
| DEVp2p Protocol and Ethereum Wire Protocol                                          | These are partially implemented but need to be completed. See Issue [#166](https://github.com/poanetwork/mana/issues/166) and Issue [#167](https://github.com/poanetwork/mana/issues/167).                                                                                                                                                                                                                                                                                                                                                                                                                       |

# Documentation

To view module and reference documentation:

1.  Generate documentation.
    `mix docs`

2.  View the generated docs.
    `open doc/index.html`

# License

Licensed under either of:

- Apache License, Version 2.0, ([LICENSE_APACHE](LICENSE_APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
- MIT license ([LICENSE_MIT](LICENSE_MIT) or http://opensource.org/licenses/MIT)

at your option.

# Contributing

See the [CONTRIBUTING](CONTRIBUTING.md) document for contribution, testing and pull request protocol.

# References

- [Ethereum yellow paper](https://ethereum.github.io/yellowpaper/paper.pdf)(Ethereum: A Secure Decentralised Generalised Transaction Ledger Byzantium Version)

- [Message Calls in Ethereum](http://www.badykov.com/ethereum/2018/06/17/message-calls-in-ethereum/)

Additional Ethereum Implementations

- [Parity-Ethereum](https://github.com/paritytech/parity-ethereum)
- [Go-Ethereum (Geth)](https://github.com/ethereum/go-ethereum/)
- [EthereumJS](https://github.com/ethereumjs/ethereumjs-vm)
- [Py-EVM](https://github.com/ethereum/py-evm)
