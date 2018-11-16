defmodule Mix.Tasks.Mana do
  @moduledoc """
  Main entry-point for the mana CLI.

  Command Line Options:

      `--chain` - Chain to load data from (default: ropsten)
      `--discovery` - Perform discovery (default: true)
      `--sync` - Perform syncing (default: true)
      `--bootnodes` - Comma separated list of bootnodes (default from chain)

  Examples:

      # Sync from a local node

      mix mana --chain ropsten --discovery false --bootnodes enode://...
  """
  use Mix.Task
  require Logger
  alias CLI.Parser
  alias CLI.StateSupervisor
  alias ExWire.Config

  @shortdoc "Starts Mana application"
  def run(args) do
    case Parser.mana_args(args) do
      {:ok, sync} ->
        {:ok, _} = setup(sync)

        # No Halt
        Process.sleep(:infinity)

      {:error, error} ->
        _ = Logger.error("Error: #{error}")
        Logger.flush()
        System.halt(1)
    end
  end

  defp setup(sync = %{debug: true}) do
    {:ok, _pid} = :net_kernel.start([:"mana@127.0.0.1", :longnames])

    true =
      :erlang.set_cookie(
        node(),
        Application.get_env(:cli, :cookie)
      )

    do_setup(sync)
  end

  defp setup(sync = %{debug: false}) do
    do_setup(sync)
  end

  defp do_setup(sync) do
    :ok = Logger.warn("Starting Mana chain #{Atom.to_string(sync.chain_name)}...")
    {:ok, _pid} = StateSupervisor.start_link(sync)

    _ =
      Config.configure!(
        chain: sync.chain_name,
        sync: sync.sync,
        discovery: sync.discovery,
        bootnodes: sync.bootnodes
      )

    Application.ensure_all_started(:ex_wire)
  end
end
