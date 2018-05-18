defmodule ExWire.Config do
  @moduledoc """
  General configuration information for ExWire.
  """

  alias Blockchain.Chain
  alias ExthCrypto.ECIES.ECDH
  alias ExthCrypto.{Signature, Key}

  @doc """
  Returns a private key that is generated when a new session is created. It is
  intended that this key is semi-persisted.
  """
  @spec private_key() :: Key.private_key()
  def private_key do
    case get_env(:private_key) do
      key when is_binary(key) ->
        key

      :random ->
        ECDH.new_ecdh_keypair()
        |> Tuple.to_list()
        |> List.last()
    end
  end

  @spec udp_network_adapter() :: atom()
  def udp_network_adapter do
    get_env(:network_adapter)
  end

  @spec public_key() :: binary()
  def public_key do
    {:ok, public_key} = Signature.get_public_key(private_key())

    public_key
  end

  @spec public_ip() :: [integer()]
  def public_ip do
    get_env(:public_ip) || [127, 0, 0, 1]
  end

  @spec node_id() :: ExWire.node_id()
  def node_id do
    public_key() |> Key.der_to_raw()
  end

  @spec listen_port() :: integer()
  def listen_port do
    get_env(:port) || 30_304
  end

  @spec protocol_version() :: integer()
  def protocol_version do
    get_env(:protocol_version)
  end

  @spec network_id() :: integer()
  def network_id do
    get_env(:network_id)
  end

  @spec p2p_version() :: integer()
  def p2p_version do
    get_env(:p2p_version)
  end

  @spec caps() :: [{String.t(), integer()}]
  def caps do
    get_env(:caps)
  end

  @spec client_id() :: String.t()
  def client_id do
    version = Mix.Project.config()[:version]
    "mana/#{version}"
  end

  @spec sync() :: boolean()
  def sync do
    get_env(:sync)
  end

  @spec bootnodes() :: [String.t()]
  def bootnodes do
    case get_env(:bootnodes) do
      nodes when is_list(nodes) ->
        nodes

      # TODO: Take all
      :from_chain ->
        chain().nodes |> Enum.take(-1)
    end
  end

  @spec chain() :: Chain.t()
  def chain do
    get_env!(:chain) |> Chain.load_chain()
  end

  @spec commitment_count() :: integer()
  def commitment_count, do: get_env!(:commitment_count)

  @spec get_env!(atom()) :: any()
  defp get_env!(key) do
    get_env(key) ||
      raise ArgumentError, message: "Please set config variable: config :ex_wire, #{key}, ..."
  end

  @spec get_env(atom()) :: any()
  defp get_env(key) do
    Application.get_env(:ex_wire, key)
  end
end
