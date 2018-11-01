#!/bin/sh

release="_build/dev/rel/mana/bin/mana"
$release eval --mfa "Mix.Tasks.Sync.run/1" --argv -- "$@"
