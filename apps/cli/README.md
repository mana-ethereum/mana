# Command-Line Interface

The CLI app builds a command-line interface for Mana.

We currently support syncing via the CLI, run as:

```bash
mana> mix sync --chain ropsten
```

Over time, with releases, we plan to evolve the CLI to function
similar to Parity, so you may see:

```bash
./mana --sync --rpc --submit-transaction "{...}"
```

The CLI tools are currently run as mix tasks, but we will also add the ability to run the CLI tools from distillery releases.

## Examples

Sync against mainnet:

```
mix sync --chain foundation --provider-url https://mainnet.infura.io/v3/<api_key>
```

Sync via RPC:

```
mix sync --chain ropsten --provider-url ipc://~/Library/Application\ Support/io.parity.ethereum/jsonrpc.ipc
```

We also support a provider argument, which currently must be RPC.

```
mix sync --provider rpc
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `cli` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:cli, "~> 0.1.0"}
  ]
end
```
