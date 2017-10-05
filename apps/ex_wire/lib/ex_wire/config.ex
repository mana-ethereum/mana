defmodule ExWire.Config do
  @moduledoc """
  General configuration information for ExWire.
  """

  @port Application.get_env(:ex_wire, :port, 30304)
  @private_key ExthCrypto.ECIES.ECDH.new_ecdh_keypair() |> Tuple.to_list() |> List.last # Application.get_env(:ex_wire, :private_key)
  @protocol_version Application.get_env(:ex_wire, :protocol_version)
  @network_id Application.get_env(:ex_wire, :network_id)
  @p2p_version Application.get_env(:ex_wire, :p2p_version)
  @caps Application.get_env(:ex_wire, :caps)
  @version Mix.Project.config[:version]

  @doc """
  Returns a private key that is generated when a new session is created. It is
  intended that this key is semi-persisted.
  """
  @spec private_key() :: ExthCrypto.Key.private_key()
  def private_key, do: @private_key
  def public_key do
    {:ok, public_key} = ExthCrypto.Signature.get_public_key(private_key())

    public_key
  end
  @spec node_id() :: ExWire.node_id
  def node_id, do: public_key() |> ExthCrypto.Key.der_to_raw

  @spec listen_port() :: integer()
  def listen_port, do: @port

  @spec protocol_version() :: integer()
  def protocol_version, do: @protocol_version

  @spec network_id() :: integer()
  def network_id, do: @network_id

  @spec p2p_version() :: integer()
  def p2p_version, do: @p2p_version

  @spec caps() :: [{String.t, integer()}]
  def caps, do: @caps

  @spec client_id() :: String.t
  def client_id, do: "Exthereum/#{@version}"

end