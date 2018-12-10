defmodule ExWire.DEVp2p.Session do
  @moduledoc """
  Module to hold struct for a DEVp2p Wire Protocol session.
  The session should be active when `Hello` messages have been exchanged.

  See https://github.com/ethereum/wiki/wiki/%C3%90%CE%9EVp2p-Wire-Protocol#session-management
  """

  alias ExWire.Packet.Capability
  alias ExWire.Packet.Capability.Mana
  alias ExWire.Packet.PacketIdMap
  alias ExWire.Packet.Protocol.Hello

  @type t :: %__MODULE__{
          hello_sent: Hello.t() | nil,
          hello_received: Hello.t() | nil,
          packet_id_map: PacketIdMap.t()
        }

  defstruct hello_sent: nil,
            hello_received: nil,
            packet_id_map: PacketIdMap.default_map()

  @doc """
  Checks whether or not the session is active.

  A session is only active if the handshake is complete and if there are overlapping capabilities, meaning
  that some of the sub-protocols are the same (e.g. eth 62)

  ## Examples

      iex> received = %ExWire.Packet.Protocol.Hello{caps: [ExWire.Packet.Capability.new({"eth", 62})]}
      iex> sent = %ExWire.Packet.Protocol.Hello{}
      iex> session = ExWire.DEVp2p.Session.hello_received(%ExWire.DEVp2p.Session{hello_sent: sent}, received)
      iex> ExWire.DEVp2p.Session.active?(session)
      true

      iex> received = %ExWire.Packet.Protocol.Hello{caps: [ExWire.Packet.Capability.new({"eth", 62})]}
      iex> session = ExWire.DEVp2p.Session.hello_received(%ExWire.DEVp2p.Session{}, received)
      iex> ExWire.DEVp2p.Session.active?(session)
      false

      iex> received = %ExWire.Packet.Protocol.Hello{caps: [ExWire.Packet.Capability.new({"eth", 61})]}
      iex> sent = %ExWire.Packet.Protocol.Hello{}
      iex> session = ExWire.DEVp2p.Session.hello_received(%ExWire.DEVp2p.Session{hello_sent: sent}, received)
      iex> ExWire.DEVp2p.Session.active?(session)
      false
  """
  @spec active?(t) :: boolean()
  def active?(session = %__MODULE__{hello_sent: sent, hello_received: received}) do
    sent != nil && received != nil && compatible_capabilities?(session)
  end

  @doc """
  Marks a session as disconnected, which simply wipes our hello messages.

  ## Examples

      iex> received = %ExWire.Packet.Protocol.Hello{caps: [ExWire.Packet.Capability.new({"eth", 62})]}
      iex> sent = %ExWire.Packet.Protocol.Hello{caps: [ExWire.Packet.Capability.new({"eth", 62})]}
      iex> session = ExWire.DEVp2p.Session.hello_received(%ExWire.DEVp2p.Session{hello_sent: sent}, received)
      iex> updated_session = ExWire.DEVp2p.Session.disconnect(session)
      iex> updated_session == %ExWire.DEVp2p.Session{}
      true
  """
  @spec disconnect(t) :: t
  def disconnect(session = %__MODULE__{}) do
    %{session | hello_sent: nil, hello_received: nil, packet_id_map: nil}
  end

  @doc """
  Updates the provided Session with the received Hello message, including setting the PacketIdMap
  based on the capabilities specified in the provided Hello message.
  """
  @spec hello_received(t, Hello.t()) :: t
  def hello_received(session, hello) do
    packet_id_map =
      hello.caps
      |> Capability.get_matching_capabilities(Mana.get_our_capabilities_map())
      |> PacketIdMap.new()

    %{session | hello_received: hello, packet_id_map: packet_id_map}
  end

  @doc """
  Determines if we have an intersection of capabilities between ourselves and
  a peer based on the caps listed in the hello messages.

  ## Examples

      iex> hello = %ExWire.Packet.Protocol.Hello{caps: [ExWire.Packet.Capability.new({"eth", 62}), ExWire.Packet.Capability.new({"mana", 14})]}
      iex> session = ExWire.DEVp2p.Session.hello_received(%ExWire.DEVp2p.Session{}, hello)
      iex> ExWire.DEVp2p.Session.compatible_capabilities?(session)
      true

      iex> hello = %ExWire.Packet.Protocol.Hello{caps: [ExWire.Packet.Capability.new({"eth", 63})]}
      iex> session = ExWire.DEVp2p.Session.hello_received(%ExWire.DEVp2p.Session{}, hello)
      iex> ExWire.DEVp2p.Session.compatible_capabilities?(session)
      false
  """
  @spec compatible_capabilities?(t) :: boolean()
  def compatible_capabilities?(%__MODULE__{packet_id_map: packet_id_map}) do
    Map.has_key?(packet_id_map.ids_to_modules, 0x10)
  end
end
