defmodule ExWire.Packet.BlockBodies do
  @moduledoc """
  Eth Wire Packet for getting block bodies from a peer.

  ```
  **BlockBodies** [`+0x06`, [`transactions_0`, `uncles_0`] , ...]

  Reply to GetBlockBodies. The items in the list (following the message ID) are
  some of the blocks, minus the header, in the format described in the main Ethereum
  specification, previously asked for in a `GetBlockBodies` message. This may
  validly contain no items if no blocks were able to be returned for the
  `GetBlockBodies` query.
  ```
  """

  require Logger

  alias ExWire.Struct.Block

  @behaviour ExWire.Packet

  @type t :: %__MODULE__{
    blocks: [Block.t]
  }

  defstruct [
    :blocks
  ]

  @doc """
  Given a BlockBodies packet, serializes for transport over Eth Wire Protocol.

  ## Examples

      iex> %ExWire.Packet.BlockBodies{
      ...>   blocks: [
      ...>     %ExWire.Struct.Block{transaction_list: [], uncle_list: []},
      ...>     %ExWire.Struct.Block{transaction_list: [], uncle_list: []}
      ...>   ]
      ...> }
      ...> |> ExWire.Packet.BlockBodies.serialize
      [[[], []], [[], []]]
  """
  @spec serialize(t) :: ExRLP.t
  def serialize(packet=%__MODULE__{}) do
    blocks = [_h|_t] = packet

    for block <- blocks, do: Block.serialize(block)
  end

  @doc """
  Given an RLP-encoded BlockBodies packet from Eth Wire Protocol,
  decodes into a BlockBodies struct.

  ## Examples

      iex> ExWire.Packet.BlockBodies.deserialize([[[], []], [[], []]])
      %ExWire.Packet.BlockBodies{
        blocks: [
          %ExWire.Struct.Block{transaction_list: [], uncle_list: []},
          %ExWire.Struct.Block{transaction_list: [], uncle_list: []}
        ]
      }
  """
  @spec deserialize(ExRLP.t) :: t
  def deserialize(rlp) do
    blocks = for block <- rlp, do: Block.deserialize(block)

    %__MODULE__{
      blocks: blocks
    }
  end

  @doc """
  Handles a BlockBodies message. This is when we have received
  a given set of blocks back from a peer.

  ## Examples

      iex> %ExWire.Packet.GetBlockBodies{hashes: [<<5>>, <<6>>]}
      ...> |> ExWire.Packet.GetBlockBodies.handle()
      :ok
  """
  @spec handle(ExWire.Packet.packet) :: ExWire.Packet.handle_response
  def handle(packet=%__MODULE__{}) do
    # TODO: Do.
    Logger.debug("[Packet] Peer sent #{Enum.count(packet.blocks)} block(s).")

    packet.blocks |> Exth.inspect("Got blocks, adding to chain")

    :ok
  end

end
