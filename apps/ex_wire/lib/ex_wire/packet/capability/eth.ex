defmodule ExWire.Packet.Capability.Eth do
  alias ExWire.Packet.Capability
  alias ExWire.Packet.Capability.Eth

  @behaviour Capability

  @version_to_packet_types %{
    62 => [
      Eth.Status,
      Eth.NewBlockHashes,
      Eth.Transactions,
      Eth.GetBlockHeaders,
      Eth.BlockHeaders,
      Eth.GetBlockBodies,
      Eth.BlockBodies,
      Eth.NewBlock
    ]
  }

  @supported_versions Map.keys(@version_to_packet_types)

  @impl true
  def get_name() do
    "eth"
  end

  @impl true
  def get_supported_versions() do
    @supported_versions
  end

  @impl true
  def get_packet_types(version) do
    case Map.get(@version_to_packet_types, version) do
      nil ->
        :unsupported_version

      packet_types ->
        packet_types
    end
  end
end
