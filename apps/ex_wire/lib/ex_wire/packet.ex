defmodule ExWire.Packet do
  @moduledoc """
  Packets handle serializing and deserializing framed packet data from
  the DevP2P and Eth Wire Protocols. They also handle how to respond
  to incoming packets.
  """

  @type packet :: struct()
  @type block_identifier :: binary() | integer()
  @type block_hash :: {binary(), integer()}

  @callback message_id_offset() :: integer()
  @callback serialize(packet) :: ExRLP.t()
  @callback deserialize(ExRLP.t()) :: packet
  # @callback summary(packet) :: String.t()

  @type handle_response ::
          :ok | :activate | :peer_disconnect | {:disconnect, atom()} | {:send, struct()}
  @callback handle(packet) :: handle_response

end
