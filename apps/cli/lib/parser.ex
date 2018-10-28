defmodule CLI.Parser do
  @moduledoc """
  Parser for command line arguments from Mix.
  """

  @type sync_arg_keywords :: [provider: String.t(), provider_url: String.t()]

  @default_provider "rpc"

  @doc """
  Parsers args for syncing

  ## Options:
    * `--provider`: String, must be "RPC" (default: RPC)
    * `--provider-url`: String, either http(s) or ipc url

  ## Examples

      iex> CLI.Parser.sync_args(["--provider", "rpc", "--provider-url", "https://mainnet.infura.io"])
      {CLI.Sync.RPC, ["https://mainnet.infura.io"], "RPC"}

      iex> CLI.Parser.sync_args(["--provider-url", "ipc:///path/to/file"])
      {CLI.Sync.RPC, ["ipc:///path/to/file"], "RPC"}

      iex> CLI.Parser.sync_args([])
      {CLI.Sync.RPC, [nil], "RPC"}
  """
  @spec sync_args([String.t()]) :: {module(), any(), String.t()} | no_return()
  def sync_args(args) do
    {kw_args, _extra} =
      OptionParser.parse!(args, switches: [provider: :string, provider_url: :string])

    provider_url = get_provider_url(kw_args)

    get_provider(kw_args, provider_url)
  end

  @spec get_provider([provider: String.t()], String.t() | nil) ::
          {module(), any(), String.t()} | no_return()
  defp get_provider(kw_args, provider_url) do
    given_provider =
      kw_args
      |> Keyword.get(:provider, @default_provider)
      |> String.trim()

    case given_provider do
      "rpc" ->
        {CLI.Sync.RPC, [provider_url], "RPC"}

      els ->
        throw("Invalid provider: #{els}")
    end
  end

  @spec get_provider_url(provider_url: String.t()) :: String.t() | no_return()
  defp get_provider_url(kw_args) do
    case Keyword.get(kw_args, :provider_url) do
      nil ->
        nil

      provider_url ->
        String.trim(provider_url)
    end
  end
end
