# Mana-Ethereum

[![CircleCI](https://circleci.com/gh/poanetwork/mana/tree/master.svg?style=svg)](https://circleci.com/gh/poanetwork/mana/tree/master) [![Waffle.io - Columns and their card count](https://badge.waffle.io/poanetwork/mana.svg?columns=all)](https://waffle.io/poanetwork/mana)

Mana-Ethereum is an open-source Ethereum blockchain client built using [Elixir](https://elixir-lang.org/). Elixir runs on the Erlang Virtual Machine, which is used for distributed systems and offers massive scalability and high visibility. These properties make Elixir a perfect candidate for blockchain network development.

In the current Ethereum ecosystem, a majority of active nodes on the network are Geth or Parity nodes. Mana-Ethereum provides an additional open-source alternative. Our aim is to create an open, well-documented implementation that closely matches the protocols described in the [Ethereum yellow paper](https://ethereum.github.io/yellowpaper/paper.pdf).

Mana-Ethereum is currently in development. See the [Project Status](#project-status) for more information.

# Dependencies

 * Elixir ~> 1.7.2
 * Rust ~> 1.26.0 (as a dependency of [Rox](https://github.com/urbint/rox))


# Installation

* Clone repo with submodules (to access the Ethereum common tests)

```
git clone --recurse-submodules https://github.com/poanetwork/mana.git
```

* Go to the mana subdirectory `cd mana`

* Run `bin/setup`

# Running a node

Currently, peer-to-peer communication is incomplete, but if you would like
to partially sync blocks, you can use an experimental script to [sync with
Infura](https://github.com/poanetwork/mana/blob/master/apps/blockchain/scripts/sync_with_infura.ex). This script downloads blocks from Infura, runs the transactions inside them then verifies the block.

## Running the sync_with_infura script

`sync_with_infura` pulls blocks from nodes hosted by
[Infura.io](https://infura.io/). You will need an Infura API key to run.

1. Sign up with [Infura](https://infura.io/register).
2. Create a new project.
3. Copy your project API KEY.
4. Paste your key into the dev.secret file for the blockchain app.
    1. Go to apps/blockchain/config/dev.secret.exs
    2. Paste your key to replace `<your api key here>` in the url string.
    ```Use Mix.Config
       config :ethereumex, url: "https://mainnet.infura.io/<your api key here>
     ```
5. Save the file and return to the mana home directory.
6. Run the script.
`mix run apps/blockchain/scripts/sync_with_infura.ex`

If running properly, you will see a timestamp in hr/min/sec/millisec and a running list of Verified Blocks.

### Infura sync issues

- When running the script mainnet fails on block [116523](https://etherscan.io/txs?block=116524) with a `state_root_mismatch` error. We believe [this transaction](https://etherscan.io/tx/0x5dd753ec16e8bf9429f7583b7cf7d4302daeb9616660051b8038da0f4b9f3e41) is causing the issue.
- Ropsten fails on block [11](https://ropsten.etherscan.io/txs?block=11) with a `state_root_mismatch` error as well.

# Testing

Run:

```
mix test
```

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

- [VMTests](https://github.com/ethereum/tests/tree/develop/VMTests/vmTests) = 100% passing
- [x] Frontier
    - [BlockchainTests](https://github.com/ethereum/tests/tree/develop/BlockchainTests) (Includes GeneralStateTests) 1325/1325 = 100% passing
    - [GeneralStateTests](https://github.com/ethereum/tests/tree/develop/GeneralStateTests) 1015/1027 = 98.8% passing
- [x] Homestead
    - [BlockchainTests](https://github.com/ethereum/tests/tree/develop/BlockchainTests) (Includes GeneralStateTests) 2231/2231 = 100% passing
    - [GeneralStateTests](https://github.com/ethereum/tests/tree/develop/GeneralStateTests) 2024/2062 = 98.2% passing
- [x] EIP150
   - [BlockchainTests](https://github.com/ethereum/tests/tree/develop/BlockchainTests) (Includes GeneralStateTests) 1275/1275 = 100% passing
   - [GeneralStateTests](https://github.com/ethereum/tests/tree/develop/GeneralStateTests) 1089/1114 = 97.8% passing
- [x] EIP158
   - [BlockchainTests](https://github.com/ethereum/tests/tree/develop/BlockchainTests) (Includes GeneralStateTests) 1229/1233 = 99.7% passing
   - [GeneralStateTests](https://github.com/ethereum/tests/tree/develop/GeneralStateTests) 1172/1181= 99.2% passing
- [ ] Byzantium
- [ ] Constantinople:  View the community [Constantinople Project Tracker](https://github.com/ethereum/pm/issues/53).


# Project Status

| Functionality | Status          |
| ------------- |-------------- |
| Encoding and Hashing | The [RLP](https://hex.pm/packages/ex_rlp) encoding protocol and the [Merkle Patricia Tree](https://github.com/poanetwork/mana/tree/master/apps/merkle_patricia_tree) data structure are fully implemented.|
| [Ethereum Virtual Machine](https://github.com/poanetwork/mana/tree/master/apps/evm) | Our EVM currently passes 100% of the common [VM tests](https://github.com/ethereum/tests/tree/develop/VMTests). We are still discovering subtle differences in our implementation such as the [“vanishing Ether” issue](https://github.com/poanetwork/mana/commit/aa3056efe341dd548a750c6f5b4c8962ccef2518). This component is for the most part complete.    |
| Peer to Peer Networking | Currently we can connect to one of the Ethereum bootnodes, get a list of peers, and add them to a list of known peers. We have fully implemented the modified [kademlia DHT](https://github.com/poanetwork/mana/tree/master/apps/ex_wire/lib/ex_wire/kademlia). <br /><br />We can also successfully perform the encrypted handshake with peer nodes and derive secrets to frame the rest of the messages. We have not yet implemented the ability to send [multi-frame packets](https://github.com/ethereum/devp2p/blob/master/rlpx.md#framing). See Issue [#97](https://github.com/poanetwork/mana/issues/97).  |
| DEVp2p Protocol and Ethereum Wire Protocol | These are partially implemented but need to be completed. See Issue [#166](https://github.com/poanetwork/mana/issues/166) and Issue [#167](https://github.com/poanetwork/mana/issues/167). |

# Documentation
To view module and reference documentation:

1. Generate documentation.
`mix docs`

2. View the generated docs.
`open doc/index.html`

# License

[![License: LGPL v3.0](https://img.shields.io/badge/License-LGPL%20v3-blue.svg)](https://www.gnu.org/licenses/lgpl-3.0)

This project is licensed under the GNU Lesser General Public License v3.0. See the [LICENSE](LICENSE) file for details.


# Contributing

See the [CONTRIBUTING](CONTRIBUTING.md) document for contribution, testing and pull request protocol.


# References

* [Ethereum yellow paper](https://ethereum.github.io/yellowpaper/paper.pdf)(Ethereum: A Secure Decentralised Generalised Transaction Ledger Byzantium Version)

* [Message Calls in Ethereum](http://www.badykov.com/ethereum/2018/06/17/message-calls-in-ethereum/)

Additional Ethereum Implementations

* [Parity-Ethereum](https://github.com/paritytech/parity-ethereum)
* [Go-Ethereum (Geth)](https://github.com/ethereum/go-ethereum/)
* [EthereumJS](https://github.com/ethereumjs/ethereumjs-vm)
* [Py-EVM](https://github.com/ethereum/py-evm)
