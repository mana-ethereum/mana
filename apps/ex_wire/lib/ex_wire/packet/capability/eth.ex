defmodule ExWire.Packet.Capability.Eth do
  alias ExWire.Config
  alias ExWire.Packet.Capability
  alias ExWire.Packet.Capability.Eth

  @behaviour Capability

  @name "eth"

  @version_to_packet_types %{
    62 => [
      Eth.Status,
      Eth.NewBlockHashes,
      Eth.Transactions,
      Eth.GetBlockHeaders,
      Eth.BlockHeaders,
      Eth.GetBlockBodies,
      Eth.BlockBodies,
      Eth.NewBlock,
      :reserved,
      :reserved,
      :reserved,
      :reserved,
      :reserved,
      :reserved,
      :reserved,
      :reserved,
      :reserved
    ],
    63 => [
      Eth.Status,
      Eth.NewBlockHashes,
      Eth.Transactions,
      Eth.GetBlockHeaders,
      Eth.BlockHeaders,
      Eth.GetBlockBodies,
      Eth.BlockBodies,
      Eth.NewBlock,
      Eth.GetNodeData,
      Eth.NodeData,
      Eth.GetReceipts,
      Eth.Receipts,
      :reserved,
      :reserved,
      :reserved,
      :reserved,
      :reserved
    ]
  }

  @available_versions Map.keys(@version_to_packet_types)
  @configured_versions Config.caps()
                       |> Enum.filter(fn cap -> cap.name == @name end)
                       |> Enum.map(fn cap -> cap.version end)

  @supported_versions Enum.filter(@available_versions, fn el ->
                        Enum.member?(@configured_versions, el)
                      end)

  @impl true
  def get_name() do
    @name
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
