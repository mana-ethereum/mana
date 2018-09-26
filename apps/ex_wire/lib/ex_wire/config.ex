defmodule ExWire.Config do
  @moduledoc """
  General configuration information for ExWire.
  """

  alias Blockchain.Chain
  alias ExWire.Crypto
  alias ExthCrypto.ECIES.ECDH
  alias ExthCrypto.{Signature, Key}

  @doc """
  Returns a private key that is generated when a new session is created.
  It is intended that this key is semi-persisted.
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

  @spec udp_network_adapter() :: {atom(), atom()}
  def udp_network_adapter do
    node_discovery_params()[:network_adapter]
  end

  @spec public_key() :: binary()
  def public_key do
    {:ok, public_key} = Signature.get_public_key(private_key())

    public_key
  end

  @spec discovery() :: boolean()
  def discovery do
    get_env(:discovery)
  end

  @spec public_ip() :: [integer()]
  def public_ip do
    get_env(:public_ip) || [127, 0, 0, 1]
  end

  @spec node_id() :: ExWire.node_id()
  def node_id do
    Crypto.node_id_from_public_key(public_key())
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

      :from_chain ->
        chain().nodes
    end
  end

  @spec chain() :: Chain.t()
  def chain do
    case get_env!(:chain) do
      chain when is_atom(chain) -> Chain.load_chain(chain)
      _ -> raise "Chain config should be an atom"
    end
  end

  @spec commitment_count() :: integer()
  def commitment_count, do: get_env!(:commitment_count)

  @spec node_discovery_params() :: Keyword.t()
  def node_discovery_params do
    get_env!(:node_discovery)
  end

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
