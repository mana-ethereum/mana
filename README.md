# Mana

[![CircleCI](https://circleci.com/gh/poanetwork/mana/tree/master.svg?style=svg)](https://circleci.com/gh/poanetwork/mana/tree/master) [![Waffle.io - Columns and their card count](https://badge.waffle.io/poanetwork/mana.svg?columns=all)](https://waffle.io/poanetwork/mana)

# Dependencies

 * Elixir ~> 1.6.5
 * Rust ~> 1.26.0 (as a dependency of [Rox](https://github.com/urbint/rox))

# Installation

* Clone repo with submodules (so you can get the shared tests),

```
git clone --recurse-submodules https://github.com/poanetwork/mana.git
```

* Run `bin/setup`

# Running a node

Currently, the peer-to-peer communication is incomplete, but if you would like
to partially sync blocks, you can use an experimental script to sync with
`Infura`:

## Running `sync_with_infura`

`sync_with_infura` pulls blocks from the nodes hosted by
[Infura.io](https://infura.io/).

First you'll need to sign up for an [api key here](https://infura.io/register).

Then copy and paste your key into the development secrets file of the blockchain
app:

```
# apps/blockchain/config/dev.secret.exs
use Mix.Config

config :ethereumex, url: "https://mainnet.infura.io/<your api key here>"
```

Next run the script:

```
mix run apps/blockchain/scripts/sync_with_infura.ex
```

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
