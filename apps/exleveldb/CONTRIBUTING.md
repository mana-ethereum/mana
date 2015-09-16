# How to contribute

If you want to contribute, here are a few things to keep in mind to make sure your patch is consistent with the rest of the module.

## Getting started

To get started, run

    git clone https://github.com/skovsgaard/exleveldb

then, run

    mix do deps.get, compile, test

to ensure you have a working build (discounting any bugs you may be fixing).

From this point, create a descriptively named, snake_cased branch, e.g.

    git branch test_fixes
    git checkout test_fixes

Then, you should be ready to get to work.

## Style

Luckily, [a great style guide for Elixir](https://github.com/niftyn8/elixir_style_guide) already exists, so if you just follow that, you should be fine.

## Before you commit

Lastly, before you commit (or more importantly, before you send the pull request), make sure your tests are passing and that - if you are adding new functionality - you have included tests covering it.
