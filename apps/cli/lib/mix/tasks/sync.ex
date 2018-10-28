defmodule Mix.Tasks.Sync do
  @moduledoc """
  Syncs the blockchain from a remote source.

  Currently, we only support syncing via JSON-RPC from either an HTTP client,
  such as Infura, or via inter-process communication (IPC) with a locally
  running node.

  Note: RPC syncing will keep the client up to date, but does not make the node
  part of the peer-to-peer community of nodes. You will not receive information
  on non-accepted blocks and you will not advertise blocks to peers.

  Command Line Options:

      `--provider` (default: rpc) - Source to pull blocks from, must be RPC.
      `--provider-url` - URL to pull RPC data from. Should either be an HTTP(s) URL
                         or an IPC url. E.g. `https://...` or `ipc:///path/to/file`.

  Examples:

      mix sync --provider-url https://ropsten.infura.io

      mix sync --provider rpc --provider-url ipc:///path/to/file
  """
  use Mix.Task

  @shortdoc "Starts sync with a provider (e.g. Infura)"
  def run(args) do
    {provider, provider_args, provider_name} = CLI.Parser.sync_args(args)

    IO.puts("Starting sync with #{provider_name}...")

    # Kick off a sync
    CLI.sync(provider, provider_args)
  end
end
