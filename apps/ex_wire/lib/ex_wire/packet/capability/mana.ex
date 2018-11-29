defmodule ExWire.Packet.Capability.Mana do
  alias ExWire.Packet.Capability.Eth

  @our_capabilities %{
    Eth.get_name() => Eth
  }

  @spec get_our_capabilities_map() :: %{atom() => module()}
  def get_our_capabilities_map() do
    @our_capabilities
  end
end