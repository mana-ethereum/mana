defmodule CLI.Parser do
  @moduledoc """
  Parses for command line arguments for the CLI.
  """
  @type sync_arg_keywords :: [provider: String.t(), provider_url: String.t()]

  @default_chain_name "ropsten"
  @default_no_discovery false
  @default_no_sync false
  @default_bootnodes "from_chain"
  @default_debug false

  @doc """
  Parsers args for syncing

  ## Options:
    * `--chain` - Chain to load data from (default: ropsten)
    * `--no-discovery` - Perform discovery (default: false)
    * `--no-sync` - Perform syncing (default: false)
    * `--bootnodes` - Comma separated list of bootnodes (default: from_chain)

  ## Examples

      iex> CLI.Parser.ManaParser.mana_args(["--chain", "ropsten", "--discovery", "false", "--sync", "false"])
      {:ok, %{
        chain_name: :ropsten,
        discovery: false,
        sync: false,
        bootnodes: :from_chain,
        debug: false
      }}

      iex> CLI.Parser.ManaParser.mana_args(["--chain", "foundation", "--bootnodes", "enode://google.com,enode://apple.com"])
      {:ok, %{
        chain_name: :foundation,
        discovery: true,
        sync: true,
        bootnodes: ["enode://google.com", "enode://apple.com"],
        debug: false
      }}

      iex> CLI.Parser.ManaParser.mana_args([])
      {:ok, %{
        chain_name: :ropsten,
        discovery: true,
        sync: true,
        bootnodes: :from_chain,
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
             debug: boolean()
           }}
          | {:error, String.t()}
  def mana_args(args) do
    {kw_args, _extra} = OptionParser.parse!(args, switches: [chain: :string, bootnodes: :string])

    with {:ok, chain_name} <- get_chain_name(kw_args),
         {:ok, discovery} <- get_discovery(kw_args),
         {:ok, sync} <- get_sync(kw_args),
         {:ok, bootnodes} <- get_bootnodes(kw_args),
         {:ok, debug} <- get_debug(kw_args) do
      {:ok,
       %{
         chain_name: chain_name,
         discovery: discovery,
         sync: sync,
         bootnodes: bootnodes,
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

    case id_from_string(given_chain_id) do
      {:ok, chain_id} ->
        {:ok, chain_id}

      :not_found ->
        {:error, "Invalid chain: #{given_chain_id}"}
    end
  end

  @spec get_discovery(discovery: boolean()) :: {:ok, boolean()} | {:error, String.t()}
  defp get_discovery(kw_args) do
    discovery =
      kw_args
      |> Keyword.get(:discovery, @default_no_discovery)

    {:ok, String.to_existing_atom(discovery)}
  end

  @spec get_sync(sync: boolean()) :: {:ok, boolean()} | {:error, String.t()}
  defp get_sync(kw_args) do
    sync =
      kw_args
      |> Keyword.get(:sync, @default_no_sync)

    {:ok, String.to_existing_atom(sync)}
  end

  @spec get_debug(debug: boolean()) :: {:ok, boolean()} | {:error, String.t()}
  defp get_debug(kw_args) do
    debug =
      kw_args
      |> Keyword.get(:sync, @default_debug)

    {:ok, String.to_existing_atom(debug)}
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

  @spec id_from_string(String.t()) :: :not_found | {:ok, :foundation | :ropsten}
  defp id_from_string("ropsten"), do: {:ok, :ropsten}
  defp id_from_string("foundation"), do: {:ok, :foundation}
  defp id_from_string(_), do: :not_found

  @spec integer_id_from_string(String.t()) :: {:ok, non_neg_integer()} | :not_found
  def integer_id_from_string("ropsten"), do: {:ok, 3}
  def integer_id_from_string("foundation"), do: {:ok, 1}
  def integer_id_from_string(_), do: :not_found
end
