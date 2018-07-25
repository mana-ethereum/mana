# Mana Ethereum Implementation

[![CircleCI](https://circleci.com/gh/poanetwork/mana/tree/master.svg?style=svg)](https://circleci.com/gh/poanetwork/mana/tree/master) [![Waffle.io - Columns and their card count](https://badge.waffle.io/poanetwork/mana.svg?columns=all)](https://waffle.io/poanetwork/mana)

Mana is an open-source Ethereum blockchain client built using [Elixir](https://elixir-lang.org/). Elixir runs on the Erlang Virtual Machine, which is used for distributed systems and offers massive scalability and high visibility. These properties make Elixir a perfect candidate for blockchain network development.

In the current Ethereum ecosystem, a majority of active nodes on the network are Geth or Parity nodes. Mana provides an additional open-source alternative. Our aim is to create an open, well-documented implementation that closely matches the protocols described in the [Ethereum yellow paper](https://ethereum.github.io/yellowpaper/paper.pdf).

Mana is currently in development.

# Dependencies

 * Elixir ~> 1.6.5
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
to partially sync blocks, you can use an experimental script to sync with
`Infura`:

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

* [Ethereum yellow paper](https://ethereum.github.io/yellowpaper/paper.pdf)(ETHEREUM: A SECURE DECENTRALISED GENERALISED TRANSACTION LEDGER
BYZANTIUM VERSION )

* [Message Calls in Ethereum](http://www.badykov.com/ethereum/2018/06/17/message-calls-in-ethereum/)

Additional Ethereum Implementations

* [Parity](https://github.com/paritytech/parity-ethereum)
* [Geth](https://github.com/ethereum/go-ethereum/)
* [EthereumJS](https://github.com/ethereumjs/ethereumjs-vm)
