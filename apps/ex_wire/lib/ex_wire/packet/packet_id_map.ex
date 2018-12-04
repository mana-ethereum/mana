defmodule ExWire.Packet.PacketIdMap do
  @moduledoc """
  Module to hold the logic for Packet lookup by ID and ID lookup by packet for a negotiated peer session.

  See: https://github.com/ethereum/devp2p/blob/master/devp2p.md#message-contents
  """

  alias ExWire.Packet
  alias ExWire.Packet.Capability
  alias ExWire.Packet.Capability.Mana
  alias ExWire.Packet.Protocol.{Disconnect, Hello, Ping, Pong}

  @starting_id 0x10

  @type t :: %__MODULE__{
          ids_to_modules: map(),
          modules_to_ids: map()
        }

  @protocol_ids_to_modules %{
    Hello.message_id_offset() => Hello,
    Disconnect.message_id_offset() => Disconnect,
    Ping.message_id_offset() => Ping,
    Pong.message_id_offset() => Pong
  }

  defstruct [
    :ids_to_modules,
    :modules_to_ids
  ]

  @doc """
  Returns the default protocol message id to packet module map that applies to all DEVp2p participants.
  """
  @spec default_map() :: t
  def default_map() do
    new()
  end

  @doc """
  Returns the PacketIdMap that results from the provided Capabilities
  in addition to the default protocol-level ones.
  """
  @spec new([Capability.t()]) :: t
  def new(capabilities \\ []) do
    {_, id_to_packet_type_map} =
      capabilities
      |> Enum.filter(fn cap ->
        Capability.are_we_capable?(cap, Mana.get_our_capabilities_map())
      end)
      |> Enum.sort(fn %Capability{name: name1}, %Capability{name: name2} -> name1 < name2 end)
      |> Enum.map(fn cap ->
        Capability.get_packets_for_capability(cap, Mana.get_our_capabilities_map())
      end)
      |> Enum.reduce(
        {@starting_id, @protocol_ids_to_modules},
        &build_capability_ids_to_modules_map/2
      )

    %__MODULE__{
      ids_to_modules: id_to_packet_type_map,
      modules_to_ids: for({k, v} <- id_to_packet_type_map, do: {v, k}) |> Enum.into(%{})
    }
  end

  @doc """
  Gets the Message ID that should be associated with the provided Packet.

  ## Examples
    # Hello example
    iex> default_map = ExWire.Packet.PacketIdMap.default_map()
    iex> ExWire.Packet.PacketIdMap.get_packet_id(default_map, %ExWire.Packet.Protocol.Hello{})
    {:ok, 0x00}

    # Unsupported Example
    iex> default_map = ExWire.Packet.PacketIdMap.default_map()
    iex> ExWire.Packet.PacketIdMap.get_packet_id(default_map, %ExWire.Packet.Capability.Eth.Status{})
    :unsupported_packet
  """
  @spec get_packet_id(t, Packet.packet()) :: {:ok, integer()} | :unsupported_packet
  def get_packet_id(map, _struct = %{__struct__: packet_module}) do
    case Map.get(map.modules_to_ids, packet_module) do
      nil ->
        :unsupported_packet

      id ->
        {:ok, id}
    end
  end

  @doc """
  Gets the Module that should be associated with the provided Message ID, given the provided PacketIdMap.

  ## Examples
    # Hello example
    iex> default_map = ExWire.Packet.PacketIdMap.default_map()
    iex> ExWire.Packet.PacketIdMap.get_packet_module(default_map, 0x00)
    {:ok, ExWire.Packet.Protocol.Hello}

    # Unsupported Example
    iex> default_map = ExWire.Packet.PacketIdMap.default_map()
    iex> ExWire.Packet.PacketIdMap.get_packet_module(default_map, 0x10)
    :unsupported_packet
  """
  @spec get_packet_module(t, integer()) :: {:ok, module()} | :unsupported_packet
  def get_packet_module(map, id) do
    case Map.get(map.ids_to_modules, id) do
      nil ->
        :unsupported_packet

      module ->
        {:ok, module}
    end
  end

  defp build_capability_ids_to_modules_map(capability_packet_types, {base_id, starting_map}) do
    capability_packet_types
    |> Enum.reduce({base_id, starting_map}, fn packet_type, {next_base_id, updated_map} ->
      if packet_type == :reserved do
        {next_base_id + 1, updated_map}
      else
        packet_id = base_id + apply(packet_type, :message_id_offset, [])

        {Kernel.max(next_base_id, packet_id + 1), Map.put(updated_map, packet_id, packet_type)}
      end
    end)
  end
end
