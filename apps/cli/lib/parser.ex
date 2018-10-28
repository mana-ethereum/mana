defmodule CLI.Parser do
  @moduledoc """
  Parser for command line arguments from Mix.
  """
  alias CLI.Sync.RPC

  @type sync_arg_keywords :: [provider: String.t(), provider_url: String.t()]

  @default_provider "rpc"
  @default_chain_id "ropsten"

  @doc """
  Parsers args for syncing

  ## Options:
    * `--chain`: Chain to sync with (default: ropsten)
    * `--provider`: String, must be "RPC" (default: RPC)
    * `--provider-url`: String, either http(s) or ipc url

  ## Examples

      iex> CLI.Parser.sync_args(["--provider", "rpc", "--provider-url", "https://mainnet.infura.io"])
      {:ok, %{
        chain_id: :ropsten,
        provider: CLI.Sync.RPC,
        provider_args: ["https://mainnet.infura.io"],
        provider_info: "RPC"
      }}

      iex> CLI.Parser.sync_args(["--provider-url", "ipc:///path/to/file"])
      {:ok, %{
        chain_id: :ropsten,
        provider: CLI.Sync.RPC,
        provider_args: ["ipc:///path/to/file"],
        provider_info: "RPC"
      }}

      iex> CLI.Parser.sync_args([])
      {:ok, %{
        chain_id: :ropsten,
        provider: CLI.Sync.RPC,
        provider_args: ["https://ropsten.infura.io"],
        provider_info: "RPC"
      }}

      iex> CLI.Parser.sync_args(["--chain", "foundation"])
      {:ok, %{
        chain_id: :foundation,
        provider: CLI.Sync.RPC,
        provider_args: ["https://foundation.infura.io"],
        provider_info: "RPC"
      }}

      iex> CLI.Parser.sync_args(["--chain", "pony"])
      {:error, "Invalid chain: pony"}
  """
  @spec sync_args([String.t()]) ::
          {:ok,
           %{
             provider: module(),
             provider_args: [any()],
             provider_info: String.t(),
             chain_id: atom()
           }}
          | {:error, String.t()}
  def sync_args(args) do
    {kw_args, _extra} =
      OptionParser.parse!(args,
        switches: [chain: :string, provider: :string, provider_url: :string]
      )

    with {:ok, chain_id} <- get_chain_id(kw_args) do
      with {:ok, provider_url} <- get_provider_url(kw_args, chain_id) do
        with {:ok, {provider, provider_args, provider_info}} = get_provider(kw_args, provider_url) do
          {:ok,
           %{
             provider: provider,
             provider_args: provider_args,
             provider_info: provider_info,
             chain_id: chain_id
           }}
        end
      end
    end
  end

  @spec get_chain_id(chain: String.t()) :: {:ok, atom()} | {:error, String.t()}
  defp get_chain_id(kw_args) do
    given_chain_id =
      kw_args
      |> Keyword.get(:chain, @default_chain_id)
      |> String.trim()

    case Blockchain.Chain.id_from_string(given_chain_id) do
      {:ok, chain_id} ->
        {:ok, chain_id}

      :not_found ->
        {:error, "Invalid chain: #{given_chain_id}"}
    end
  end

  @spec get_provider_url([provider_url: String.t()], atom()) ::
          {:ok, String.t()} | {:error, String.t()}
  defp get_provider_url(kw_args, chain_id) do
    case Keyword.get(kw_args, :provider_url) do
      nil ->
        {:ok, get_infura_url(chain_id)}

      provider_url ->
        {:ok, String.trim(provider_url)}
    end
  end

  @spec get_provider([provider: String.t()], String.t() | nil) ::
          {:ok, {module(), any(), String.t()}} | {:error, String.t()}
  defp get_provider(kw_args, provider_url) do
    given_provider =
      kw_args
      |> Keyword.get(:provider, @default_provider)
      |> String.trim()

    case given_provider do
      "rpc" ->
        {:ok, {RPC, [provider_url], "RPC"}}

      els ->
        {:error, "Invalid provider: #{els}"}
    end
  end

  @spec get_infura_url(atom()) :: String.t()
  defp get_infura_url(chain_id) do
    "https://#{Atom.to_string(chain_id)}.infura.io"
  end
end
