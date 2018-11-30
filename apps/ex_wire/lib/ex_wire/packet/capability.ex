defmodule ExWire.Packet.Capability do
  @moduledoc """
  Module to hold all logic for DEVp2p Wire Protocol capabilities, negotiation, and Message IDs.

  See: https://github.com/ethereum/devp2p/blob/master/devp2p.md#message-contents
  """

  @type t :: %__MODULE__{
          name: String.t(),
          version: integer()
        }

  defstruct [
    :name,
    :version
  ]

  @callback get_name() :: String.t()
  @callback get_supported_versions() :: [integer()]
  @callback get_packet_types(integer()) :: [module()] | :unsupported_version

  @spec new({String.t(), integer()}) :: t
  def new({name, version}) do
    %__MODULE__{
      name: String.downcase(name),
      version: version
    }
  end

  @spec get_matching_capabilities([t], %{String.t() => module()}) :: [t]
  def get_matching_capabilities(peer_capabilities, mana_capabilities_map) do
    peer_capabilities
    |> Enum.filter(fn cap -> are_we_capable?(cap, mana_capabilities_map) end)
    |> Enum.sort(&sort_asc_name_desc_version/2)
    |> Enum.dedup_by(fn %__MODULE__{name: name} -> name end)
  end

  @spec get_packets_for_capability(t, %{String.t() => module()}) ::
          [module()] | :unsupported_capability | :unsupported_version
  def get_packets_for_capability(%__MODULE__{name: name, version: version}, mana_capabilities_map) do
    case Map.get(mana_capabilities_map, name) do
      nil ->
        :unsupported_capability

      capability ->
        apply(capability, :get_packet_types, [version])
    end
  end

  @spec are_we_capable?(t, %{String.t() => module()}) :: boolean()
  def are_we_capable?(%__MODULE__{name: name, version: version}, mana_capabilities_map) do
    Map.has_key?(mana_capabilities_map, name) &&
      apply(Map.get(mana_capabilities_map, name), :get_packet_types, [version]) !=
        :unsupported_version
  end

  defp sort_asc_name_desc_version(first = %__MODULE__{}, second = %__MODULE__{}) do
    {first.name, first.version} < {second.name, second.version}
  end
end
