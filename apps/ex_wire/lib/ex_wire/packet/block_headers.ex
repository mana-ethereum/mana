defmodule ExWire.Packet.BlockHeaders do
  @moduledoc """
  Eth Wire Packet for getting block headers from a peer.

  ```
  **BlockHeaders** [`+0x04`, `blockHeader_0`, `blockHeader_1`, ...]

  Reply to `GetBlockHeaders`. The items in the list (following the message ID) are
  block headers in the format described in the main Ethereum specification, previously
  asked for in a `GetBlockHeaders` message. This may validly contain no block headers
  if no block headers were able to be returned for the `GetBlockHeaders` query.
  ```
  """

  require Logger

  @behaviour ExWire.Packet

  @type t :: %__MODULE__{
    headers: [Block.Header.t]
  }

  defstruct [
    :headers
  ]

  @doc """
  Given a BlockHeaders packet, serializes for transport over Eth Wire Protocol.

  ## Examples

      iex> %ExWire.Packet.BlockHeaders{
      ...>   headers: [
      ...>     [1, 2, 3]
      ...>     [4, 5, 6]
      ...>   ]
      ...> }
      ...> |> ExWire.Packet.BlockHeaders.serialize
      [ [1, 2, 3], [4, 5, 6] ]
  """
  @spec serialize(t) :: ExRLP.t
  def serialize(packet=%__MODULE__{}) do
    for header <- packet.headers, do: Block.Header.serialize(header)
  end

  @doc """
  Given an RLP-encoded BlockBodies packet from Eth Wire Protocol,
  decodes into a BlockBodies struct.

  ## Examples

      iex> ExWire.Packet.BlockHeaders.deserialize([ [1, 2, 3], [4, 5, 6] ])
      %ExWire.Packet.BlockHeaders{
        headers: [
          [1, 2, 3],
          [4, 5, 6]
        ]
      }
  """
  @spec deserialize(ExRLP.t) :: t
  def deserialize(rlp) do
    headers = for header <- rlp, do: Block.Header.deserialize(header)

    %__MODULE__{
      headers: headers
    }
  end

  @doc """
  Handles a BlockHeaders message. This is when we have received
  a given set of block headers back from a peer.

  ## Examples

      iex> %ExWire.Packet.GetBlockHeaders{headers: [ [1, 2, 3], [4, 5, 6] ]}
      ...> |> ExWire.Packet.GetBlockHeaders.handle()
      :ok
  """
  @spec handle(ExWire.Packet.packet) :: ExWire.Packet.handle_response
  def handle(packet=%__MODULE__{}) do
    # TODO: Do.
    Logger.debug("[Packet] Peer sent #{Enum.count(packet.headers)} header(s)")

    # packet.headers |> Exth.inspect("Got headers, requesting more?")

    :ok
  end

end
