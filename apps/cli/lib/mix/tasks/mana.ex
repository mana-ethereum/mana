defmodule Mix.Tasks.Mana do
  @moduledoc """
  Main entry-point for the mana CLI.

  Command Line Options:
    * `--chain` - Chain to load data from (default: ropsten)
    * `--no-discovery` - Perform discovery (default: false)
    * `--no-sync` - Perform syncing (default: false)
    * `--bootnodes` - Comma separated list of bootnodes (default: from_chain)
    * `--debug` - Add remote debugging (default: false)

  Examples:

      # Sync from a local node

      mix mana --chain ropsten --discovery false --bootnodes enode://...

      # Sync from a local node with warp (alpha)

      mix mana --chain ropsten --discovery false --bootnodes enode://... --warp

      # Start main-net node

      mix mana --chain foundation
  """
  use Mix.Task
  require Logger

  @shortdoc "Starts Mana application"
  def run(args) do
    case CLI.Parser.ManaParser.mana_args(args) do
      {:ok,
       %{
         chain_name: chain_name,
         discovery: discovery,
         sync: sync,
         bootnodes: bootnodes,
         warp: warp,
         fast: fast,
         debug: debug
       }} ->
        :ok = Logger.warn("Starting mana chain #{Atom.to_string(chain_name)}...")

        configure_debug(debug)

        :ok =
          ExWire.Config.configure!(
            chain: chain_name,
            sync: sync,
            discovery: discovery,
            bootnodes: bootnodes,
            warp: warp,
            fast: fast
          )

        {:ok, _} = Application.ensure_all_started(:ex_wire)

      # No Halt
      # Process.sleep(:infinity)

      {:error, error} ->
        _ = Logger.error("Error: #{error}")
        Logger.flush()
        System.halt(1)
    end
  end

  @spec configure_debug(boolean()) :: :ok
  defp configure_debug(false), do: :ok

  defp configure_debug(true) do
    {:ok, _pid} = :net_kernel.start([:"mana@127.0.0.1", :longnames])

    true =
      :erlang.set_cookie(
        node(),
        Application.get_env(:cli, :cookie)
      )

    :ok
  end
end
