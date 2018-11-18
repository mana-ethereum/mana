#!/bin/sh

release_ctl eval --mfa "Mix.Tasks.Mana.run/1" --argv -- --extra "$@"
