defmodule ExWire.Packet do
  @moduledoc """
  Packets handle serializing and deserializing framed packet data from
  the DevP2P and Eth Wire Protocols. They also handle how to respond
  to incoming packets.
  """
  alias ExWire.Packet.Capability
  @type packet :: struct()
  @type block_identifier :: binary() | integer()
  @type block_hash :: {binary(), integer()}
  @type p2p_version :: non_neg_integer()

  @callback message_id_offset() :: integer()
  @callback serialize(packet) :: ExRLP.t()
  @callback deserialize(ExRLP.t()) :: packet
  # @callback summary(packet) :: String.t()

  @type handle_response ::
          :ok
          | {:activate, [Capability.t()], p2p_version()}
          | :peer_disconnect
          # hello
          | {:disconnect, atom(), [Capability.t()], p2p_version()}
          # status
          | {:disconnect, atom()}
          | {:send, struct()}
  @callback handle(packet) :: handle_response
end
