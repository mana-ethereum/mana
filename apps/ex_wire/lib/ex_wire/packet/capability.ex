defmodule ExWire.Packet.Capability do
  @moduledoc """
  Module to hold all logic for DEVp2p Wire Protocol capabilities, negotiation, and Message IDs.

  See: https://github.com/ethereum/devp2p/blob/master/devp2p.md#message-contents
  """

  @type t :: %__MODULE__{
          name: atom(),
          version: integer()
        }

  defstruct [
    :name,
    :version
  ]

  @callback get_name() :: atom()
  @callback get_supported_versions() :: [integer()]
  @callback get_packet_types(integer()) :: [module()] | :unsupported_version

  @spec new({atom(), integer()}) :: t
  def new({name, version}) when is_atom(name) do
    %__MODULE__{
      name: name,
      version: version
    }
  end

  @spec new({String.t(), integer()}) :: t
  def new({name, version}) do
    %__MODULE__{
      name: String.to_atom(name),
      version: version
    }
  end

  @spec get_matching_capabilities([t], %{atom() => module()}) :: [t]
  def get_matching_capabilities(peer_capabilities, mana_capabilities_map) do
    peer_capabilities
    |> Enum.filter(fn cap -> are_we_capable?(cap, mana_capabilities_map) end)
    |> Enum.sort(&sort_asc_name_desc_version/2)
    |> Enum.dedup_by(fn %__MODULE__{name: name} -> name end)
  end

  @spec get_packets_for_capability(t, %{atom() => module()}) ::
          [module()] | :unsupported_capability | :unsupported_version
  def get_packets_for_capability(%__MODULE__{name: name, version: version}, mana_capabilities_map) do
    case Map.get(mana_capabilities_map, name) do
      nil ->
        :unsupported_capability

      capability ->
        apply(capability, :get_packet_types, [version])
    end
  end

  @spec are_we_capable?(t, %{atom() => module()}) :: boolean()
  def are_we_capable?(%__MODULE__{name: name, version: version}, mana_capabilities_map) do
    Map.has_key?(mana_capabilities_map, name) &&
      apply(Map.get(mana_capabilities_map, name), :get_packet_types, [version]) !=
        :unsupported_version
  end

  defp sort_asc_name_desc_version(%__MODULE__{name: name1, version: version1}, %__MODULE__{
         name: name2,
         version: version2
       }) do
    name1 < name2 || (name1 == name2 && version1 > version2)
  end
end
