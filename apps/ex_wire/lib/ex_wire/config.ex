defmodule ExWire.Config do
  @moduledoc """
  General configuration information for ExWire.

  All configuration that comes from `config/*.exs`,
  or possibly the command-line or environment should
  come from this module.
  """
  alias Blockchain.Chain
  alias ExthCrypto.ECIES.ECDH
  alias ExthCrypto.{Key, Signature}
  alias ExWire.Packet.Capability

  @default_port 30_303
  @default_public_ip [127, 0, 0, 1]
  @type env_keys ::
          :bootnodes
          | :caps
          | :chain
          | :commitment_count
          | :db_root
          | :discovery
          | :mana_version
          | :node_discovery
          | :p2p_version
          | :private_key
          | :protocol_version
          | :public_ip
          | :sync
          | :warp

  @doc """
  Allows application to configure ExWire before it starts.
  """
  @spec configure!(keyword(env_keys)) :: :ok | no_return()
  def configure!(kw_args) do
    if Enum.member?(Application.started_applications(), :ex_wire) do
      throw("Cannot configure ExWire after started")
    end

    for {env_key, env_val} <- kw_args do
      Application.put_env(:ex_wire, env_key, env_val, persistent: true)
    end

    :ok
  end

  @doc """
  Returns a private key that is generated when a new session is created.

  Note: if the key is set to random, this will persist the key so it is
        identical for later calls.

  It is intended that this key is semi-persisted.
  """
  @spec private_key() :: Key.private_key()
  def private_key() do
    case get_env([], :private_key) do
      key when is_binary(key) ->
        key

      :random ->
        ECDH.new_ecdh_keypair()
        |> Tuple.to_list()
        |> List.last()
        |> set_env!(:private_key)
    end
  end

  @spec udp_network_adapter(Keyword.t()) :: {atom(), atom()}
  def udp_network_adapter(given_params \\ []) do
    node_discovery_params(given_params, :network_adapter)
  end

  @spec public_key() :: Key.public_key()
  def public_key() do
    {:ok, public_key} = Signature.get_public_key(private_key())

    public_key
  end

  @spec public_node_url() :: String.t()
  def public_node_url() do
    my_public_key_encoded =
      public_key()
      |> Base.encode16(case: :lower)

    my_port = listen_port()
    # TODO: This is only valid for IPv4 addresses
    my_public_ip =
      public_ip()
      |> Enum.map(fn digit -> to_string(digit) end)
      |> Enum.join(".")

    "enode://#{my_public_key_encoded}@#{my_public_ip}:#{my_port}"
  end

  @spec perform_discovery?(Keyword.t()) :: boolean()
  def perform_discovery?(given_params \\ []) do
    if discovery_str = System.get_env("DISCOVERY") do
      coerce_boolean(discovery_str)
    else
      get_env(given_params, :discovery, false)
    end
  end

  @spec public_ip(Keyword.t()) :: [integer()]
  def public_ip(given_params \\ []) do
    if conf_ip = System.get_env("EXT_IP_ADDRESS") do
      conf_ip
      |> String.split(".")
      |> Enum.map(&String.to_integer/1)
    else
      get_env(given_params, :public_ip, @default_public_ip)
    end
  end

  @spec node_id() :: ExWire.node_id()
  def node_id() do
    ExWire.Crypto.node_id_from_public_key(public_key())
  end

  @spec listen_port(Keyword.t()) :: integer()
  def listen_port(given_params \\ []) do
    node_discovery_params(given_params, :port, @default_port)
  end

  @spec protocol_version(Keyword.t()) :: integer()
  def protocol_version(given_params \\ []) do
    get_env(given_params, :protocol_version)
  end

  @spec p2p_version(Keyword.t()) :: integer()
  def p2p_version(given_params \\ []) do
    get_env(given_params, :p2p_version)
  end

  @spec caps(Keyword.t()) :: [Capability.t()]
  def caps(given_params \\ []) do
    caps = get_env(given_params, :caps, [])
    Enum.map(caps, &Capability.new/1)
  end

  @spec client_id() :: String.t()
  def client_id() do
    "mana/#{get_env([], :mana_version)}"
  end

  @spec perform_sync?(Keyword.t()) :: boolean()
  def perform_sync?(given_params \\ []) do
    get_env(given_params, :sync)
  end

  @spec warp?(Keyword.t()) :: boolean()
  def warp?(given_params \\ []) do
    get_env(given_params, :warp)
  end

  @spec bootnodes(Keyword.t()) :: [String.t()]
  def bootnodes(given_params \\ []) do
    if conf_ip = System.get_env("BOOTNODES") do
      conf_ip
      |> String.split(",")
    else
      case get_env(given_params, :bootnodes) do
        nodes when is_list(nodes) ->
          nodes

        :from_chain ->
          chain().nodes
      end
    end
  end

  @spec chain(Keyword.t()) :: Chain.t()
  def chain(given_params \\ []) do
    case get_env!(given_params, :chain) do
      chain when is_atom(chain) -> Chain.load_chain(chain)
      _ -> raise "Chain config should be an atom"
    end
  end

  @spec db_name(Chain.t()) :: charlist()
  def db_name(chain) do
    db_root = get_env!([], :db_root)
    chain_db_path = Path.join(db_root, "mana-#{String.downcase(chain.name)}")
    String.to_charlist(chain_db_path)
  end

  @spec commitment_count(Keyword.t()) :: integer()
  def commitment_count(given_params \\ []), do: get_env!(given_params, :commitment_count)

  @spec node_discovery_params(Keyword.t(), atom(), any()) :: any()
  def node_discovery_params(given_params, key, default \\ nil) do
    Keyword.get(
      get_env!(given_params, :node_discovery),
      key,
      default
    )
  end

  @spec get_env!(Keyword.t(), env_keys()) :: any()
  def get_env!(given_params, key) do
    cond do
      keyword_res = Keyword.get(given_params, key) ->
        keyword_res

      env_res = get_env([], key) ->
        env_res

      true ->
        raise ArgumentError, message: "Please set config variable: config :ex_wire, #{key}, ..."
    end
  end

  @spec get_env(Keyword.t(), env_keys(), any()) :: any()
  def get_env(given_params, key, default \\ nil) do
    if res = Keyword.get(given_params, key) do
      res
    else
      Application.get_env(:ex_wire, key, default)
    end
  end

  @spec set_env!(any(), env_keys()) :: any()
  def set_env!(value, key) do
    Application.put_env(:ex_wire, key, value)

    value
  end

  @spec coerce_boolean(String.t()) :: boolean()
  defp coerce_boolean("TRUE"), do: true
  defp coerce_boolean("true"), do: true
  defp coerce_boolean("T"), do: true
  defp coerce_boolean("t"), do: true
  defp coerce_boolean("1"), do: true
  defp coerce_boolean(_), do: false
end
