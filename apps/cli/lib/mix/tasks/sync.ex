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

      `--chain` - Chain to load data from (default: ropsten)
      `--provider` - Source to pull blocks from, must be RPC. (default: rpc)
      `--provider-url` - URL to pull RPC data from. Should either be an HTTP(s) URL
                         or an IPC url. E.g. `https://...` or `ipc:///path/to/file`.
                         Default: `https://${chain}.infura.io`

  Examples:

      mix sync --chain ropsten --provider-url https://ropsten.infura.io

      mix sync --chain ropsten --provider-url ipc:///path/to/file
  """
  use Mix.Task
  require Logger

  @shortdoc "Starts sync with a provider (e.g. Infura)"
  def run(args) do
    case CLI.Parser.SyncParser.sync_args(args) do
      {:ok,
       %{
         chain_id: chain_id,
         provider: provider,
         provider_args: provider_args,
         provider_info: provider_info
       }} ->
        :ok =
          Logger.warn("Starting sync with #{Atom.to_string(chain_id)} via #{provider_info}...")

        # Kick off a sync
        CLI.sync(chain_id, provider, provider_args)

      {:error, error} ->
        _ = Logger.error("Error: #{error}")
        Logger.flush()
        System.halt(1)
    end
  end
end
