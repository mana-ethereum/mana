# Mana

[![CircleCI](https://circleci.com/gh/poanetwork/mana/tree/master.svg?style=svg)](https://circleci.com/gh/poanetwork/mana/tree/master) [![Waffle.io - Columns and their card count](https://badge.waffle.io/poanetwork/mana.svg?columns=all)](https://waffle.io/poanetwork/mana)

# Requirements

Make sure you have `automake` && `autoconf` installed. If you don't, you can get
them from homebrew,

```
brew install automake
brew install autoconf
```

Since we are using [RocksDB](https://rocksdb.org/) via
[rox](https://github.com/urbint/rox), you will need to have the Rust available
at compile time,

```
brew install rust
```

# Installation

* Clone repo with submodules (so you can get the shared tests),

```
git clone --recurse-submodules https://gihub.com/poanetwork/mana.git
```

* Run `mix deps.get`
