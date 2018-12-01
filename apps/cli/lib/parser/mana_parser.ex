defmodule CLI.Parser.ManaParser do
  @moduledoc """
  Parses for command line arguments for the CLI.
  """

  @default_chain_name "ropsten"
  @default_no_discovery false
  @default_no_sync false
  @default_bootnodes "from_chain"
  @default_warp false
  @default_debug false

  @doc """
  Parses args for the mana task (also the run release task).

  ## Options:
    * `--chain` - Chain to load data from (default: ropsten)
    * `--no-discovery` - Perform discovery (default: false)
    * `--no-sync` - Perform syncing (default: false)
    * `--bootnodes` - Comma separated list of bootnodes (default: from_chain)
    * `--warp` - Perform warp sync (default: false)
    * `--debug` - Add remote debugging (default: false)

  ## Examples

      iex> CLI.Parser.ManaParser.mana_args(["--chain", "ropsten", "--no-discovery", "--no-sync"])
      {:ok, %{
        chain_name: :ropsten,
        discovery: false,
        sync: false,
        bootnodes: :from_chain,
        warp: false,
        debug: false
      }}

      iex> CLI.Parser.ManaParser.mana_args(["--chain", "foundation", "--bootnodes", "enode://google.com,enode://apple.com", "--warp", "--debug"])
      {:ok, %{
        chain_name: :foundation,
        discovery: true,
        sync: true,
        bootnodes: ["enode://google.com", "enode://apple.com"],
        warp: true,
        debug: true
      }}

      iex> CLI.Parser.ManaParser.mana_args([])
      {:ok, %{
        chain_name: :ropsten,
        discovery: true,
        sync: true,
        bootnodes: :from_chain,
        warp: false,
        debug: false
      }}

      iex> CLI.Parser.ManaParser.mana_args(["--chain", "pony"])
      {:error, "Invalid chain: pony"}
  """
  @spec mana_args([String.t()]) ::
          {:ok,
           %{
             chain_name: atom(),
             discovery: boolean(),
             sync: boolean(),
             bootnodes: :from_chain | list(String.t()),
             warp: boolean(),
             debug: boolean()
           }}
          | {:error, String.t()}
  def mana_args(args) do
    {kw_args, _extra} =
      OptionParser.parse!(args,
        switches: [
          chain: :string,
          no_discovery: :boolean,
          no_sync: :boolean,
          bootnodes: :string,
          warp: :boolean,
          debug: :boolean
        ]
      )

    with {:ok, chain_name} <- get_chain_name(kw_args),
         {:ok, discovery} <- get_discovery(kw_args),
         {:ok, sync} <- get_sync(kw_args),
         {:ok, bootnodes} <- get_bootnodes(kw_args),
         {:ok, warp} <- get_warp(kw_args),
         {:ok, debug} <- get_debug(kw_args) do
      {:ok,
       %{
         chain_name: chain_name,
         discovery: discovery,
         sync: sync,
         bootnodes: bootnodes,
         warp: warp,
         debug: debug
       }}
    end
  end

  @spec get_chain_name(chain: String.t()) :: {:ok, atom()} | {:error, String.t()}
  defp get_chain_name(kw_args) do
    given_chain_id =
      kw_args
      |> Keyword.get(:chain, @default_chain_name)
      |> String.trim()

    case Blockchain.Chain.id_from_string(given_chain_id) do
      {:ok, chain_id} ->
        {:ok, chain_id}

      :not_found ->
        {:error, "Invalid chain: #{given_chain_id}"}
    end
  end

  @spec get_discovery(no_discovery: boolean()) :: {:ok, boolean()} | {:error, String.t()}
  defp get_discovery(kw_args) do
    given_no_discovery =
      kw_args
      |> Keyword.get(:no_discovery, @default_no_discovery)

    {:ok, !given_no_discovery}
  end

  @spec get_sync(no_sync: boolean()) :: {:ok, boolean()} | {:error, String.t()}
  defp get_sync(kw_args) do
    given_no_sync =
      kw_args
      |> Keyword.get(:no_sync, @default_no_sync)

    {:ok, !given_no_sync}
  end

  @spec get_bootnodes(bootnodes: String.t()) ::
          {:ok, atom() | list(String.t())} | {:error, String.t()}
  defp get_bootnodes(kw_args) do
    given_bootnodes =
      kw_args
      |> Keyword.get(:bootnodes, @default_bootnodes)
      |> String.trim()

    case given_bootnodes do
      "from_chain" ->
        {:ok, :from_chain}

      _ ->
        {:ok, String.split(given_bootnodes, ",")}
    end
  end

  @spec get_warp(warp: boolean()) :: {:ok, boolean()} | {:error, String.t()}
  defp get_warp(kw_args) do
    given_warp =
      kw_args
      |> Keyword.get(:warp, @default_warp)

    {:ok, given_warp}
  end

  @spec get_debug(debug: boolean()) :: {:ok, boolean()} | {:error, String.t()}
  defp get_debug(kw_args) do
    given_debug =
      kw_args
      |> Keyword.get(:debug, @default_debug)

    {:ok, given_debug}
  end
end
