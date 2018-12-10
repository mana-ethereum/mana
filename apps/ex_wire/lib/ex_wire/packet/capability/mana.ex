defmodule ExWire.Packet.Capability.Mana do
  alias ExWire.Packet.Capability
  alias ExWire.Packet.Capability.Eth
  alias ExWire.Packet.Capability.Par

  @our_capabilities_map %{
    Eth.get_name() => Eth,
    Par.get_name() => Par
  }

  @our_capabilities @our_capabilities_map
                    |> Enum.map(fn {name, mod} ->
                      versions = apply(mod, :get_supported_versions, [])

                      versions
                      |> Enum.map(fn version -> Capability.new({name, version}) end)
                    end)
                    |> List.flatten()

  def get_our_capabilities_map() do
    @our_capabilities_map
  end

  @spec get_our_capabilities() :: [Capability.t()]
  def get_our_capabilities() do
    @our_capabilities
  end
end
