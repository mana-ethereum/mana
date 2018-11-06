defmodule ExWire.Packet.BlockBodies do
  @moduledoc """
  Eth Wire Packet for getting block bodies from a peer.

  ```
  **BlockBodies** [`+0x06`, [`transactions_0`, `uncles_0`] , ...]

  Reply to `GetBlockBodies`. The items in the list (following the message ID) are
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
          blocks: [Block.t()]
        }

  defstruct [
    :blocks
  ]

  @doc """
  Given a BlockBodies packet, serializes for transport over Eth Wire Protocol.

  ## Examples

      iex> %ExWire.Packet.BlockBodies{
      ...>   blocks: [
      ...>     %ExWire.Struct.Block{transactions_list: [[<<5>>, <<6>>, <<7>>, <<1::160>>, <<8>>, "hi", <<27>>, <<9>>, <<10>>]], ommers: [<<1::256>>]},
      ...>     %ExWire.Struct.Block{transactions_list: [[<<6>>, <<6>>, <<7>>, <<1::160>>, <<8>>, "hi", <<27>>, <<9>>, <<10>>]], ommers: [<<1::256>>]}
      ...>   ]
      ...> }
      ...> |> ExWire.Packet.BlockBodies.serialize()
      [ [[[<<5>>, <<6>>, <<7>>, <<1::160>>, <<8>>, "hi", <<27>>, <<9>>, <<10>>]], [<<1::256>>]], [[[<<6>>, <<6>>, <<7>>, <<1::160>>, <<8>>, "hi", <<27>>, <<9>>, <<10>>]], [<<1::256>>]] ]
  """
  @spec serialize(t) :: ExRLP.t()
  def serialize(packet = %__MODULE__{}) do
    for block <- packet.blocks, do: Block.serialize(block)
  end

  @doc """
  Given an RLP-encoded BlockBodies packet from Eth Wire Protocol,
  decodes into a BlockBodies struct.

  ## Examples

      iex> ExWire.Packet.BlockBodies.deserialize([ [[[<<5>>, <<6>>, <<7>>, <<1::160>>, <<8>>, "hi", <<27>>, <<9>>, <<10>>]], [<<1::256>>]], [[[<<6>>, <<6>>, <<7>>, <<1::160>>, <<8>>, "hi", <<27>>, <<9>>, <<10>>]], [<<1::256>>]] ])
      %ExWire.Packet.BlockBodies{
        blocks: [
          %ExWire.Struct.Block{
            transactions_list: [[<<5>>, <<6>>, <<7>>, <<1::160>>, <<8>>, "hi", <<27>>, <<9>>, <<10>>]],
            transactions: [%Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1::160>>, value: 8, v: 27, r: 9, s: 10, data: "hi"}],
            ommers: [<<1::256>>]
          },
          %ExWire.Struct.Block{
            transactions_list: [[<<6>>, <<6>>, <<7>>, <<1::160>>, <<8>>, "hi", <<27>>, <<9>>, <<10>>]],
            transactions: [%Blockchain.Transaction{nonce: 6, gas_price: 6, gas_limit: 7, to: <<1::160>>, value: 8, v: 27, r: 9, s: 10, data: "hi"}],
            ommers: [<<1::256>>]
          }
        ]
      }
  """
  @spec deserialize(ExRLP.t()) :: t
  def deserialize(rlp) do
    blocks = for block <- rlp, do: Block.deserialize(block)

    %__MODULE__{
      blocks: blocks
    }
  end

  # @impl true
  # def describe(%__MODULE__{blocks: blocks}) do
  # end

  @doc """
  Handles a BlockBodies message. This is when we have received
  a given set of blocks back from a peer.

  ## Examples

      iex> %ExWire.Packet.GetBlockBodies{hashes: [<<5>>, <<6>>]}
      ...> |> ExWire.Packet.GetBlockBodies.handle()
      :ok
  """
  @spec handle(ExWire.Packet.packet()) :: ExWire.Packet.handle_response()
  def handle(packet = %__MODULE__{}) do
    :ok = Logger.info("[Packet] Peer sent #{Enum.count(packet.blocks)} block(s).")

    :ok
  end
end
