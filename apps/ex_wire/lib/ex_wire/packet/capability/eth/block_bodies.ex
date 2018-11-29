defmodule ExWire.Packet.Capability.Eth.BlockBodies do
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

  @spec new([Block.t()]) :: t()
  def new(block_structs) do
    %__MODULE__{
      blocks: block_structs
    }
  end

  @doc """
  Returns the relative message id offset for this message.
  This will help determine what its message ID is relative to other Packets in the same Capability.
  """
  @impl true
  @spec message_id_offset() :: 6
  def message_id_offset do
    0x06
  end

  @doc """
  Given a BlockBodies packet, serializes for transport over Eth Wire Protocol.

  ## Examples

      iex> %ExWire.Packet.Capability.Eth.BlockBodies{
      ...>   blocks: [
      ...>     %ExWire.Struct.Block{transactions_rlp: [[<<5>>, <<6>>, <<7>>, <<1::160>>, <<8>>, "hi", <<27>>, <<9>>, <<10>>]], ommers_rlp: [[<<1::256>>, <<2::256>>, <<3::160>>, <<4::256>>, <<5::256>>, <<6::256>>, <<>>, <<5>>, <<1>>, <<5>>, <<3>>, <<6>>, "Hi mom", <<7::256>>, <<8::64>>]]},
      ...>     %ExWire.Struct.Block{transactions_rlp: [[<<6>>, <<6>>, <<7>>, <<1::160>>, <<8>>, "hi", <<27>>, <<9>>, <<10>>]], ommers_rlp: [[<<1::256>>, <<2::256>>, <<3::160>>, <<4::256>>, <<5::256>>, <<6::256>>, <<>>, <<5>>, <<1>>, <<5>>, <<3>>, <<6>>, "Hi mom", <<7::256>>, <<8::64>>]]}
      ...>   ]
      ...> }
      ...> |> ExWire.Packet.Capability.Eth.BlockBodies.serialize()
      [
        [
          [[<<5>>, <<6>>, <<7>>, <<1::160>>, <<8>>, "hi", <<27>>, <<9>>, <<10>>]],
          [[<<1::256>>, <<2::256>>, <<3::160>>, <<4::256>>, <<5::256>>, <<6::256>>, <<>>, <<5>>, <<1>>, <<5>>, <<3>>, <<6>>, "Hi mom", <<7::256>>, <<8::64>>]]
        ],
        [
          [[<<6>>, <<6>>, <<7>>, <<1::160>>, <<8>>, "hi", <<27>>, <<9>>, <<10>>]],
          [[<<1::256>>, <<2::256>>, <<3::160>>, <<4::256>>, <<5::256>>, <<6::256>>, <<>>, <<5>>, <<1>>, <<5>>, <<3>>, <<6>>, "Hi mom", <<7::256>>, <<8::64>>]]
        ]
      ]
  """
  @impl true
  @spec serialize(t) :: ExRLP.t()
  def serialize(packet = %__MODULE__{}) do
    for block <- packet.blocks, do: Block.serialize(block)
  end

  @doc """
  Given an RLP-encoded BlockBodies packet from Eth Wire Protocol, decodes into
  a `BlockBodies` struct.

  ## Examples

      iex> ExWire.Packet.Capability.Eth.BlockBodies.deserialize([ [[[<<5>>, <<6>>, <<7>>, <<1::160>>, <<8>>, "hi", <<27>>, <<9>>, <<10>>]], [[<<1::256>>, <<2::256>>, <<3::160>>, <<4::256>>, <<5::256>>, <<6::256>>, <<>>, <<5>>, <<1>>, <<5>>, <<3>>, <<6>>, "Hi mom", <<7::256>>, <<8::64>>]]], [[[<<6>>, <<6>>, <<7>>, <<1::160>>, <<8>>, "hi", <<27>>, <<9>>, <<10>>]], [[<<1::256>>, <<2::256>>, <<3::160>>, <<4::256>>, <<5::256>>, <<6::256>>, <<>>, <<5>>, <<1>>, <<5>>, <<3>>, <<6>>, "Hi mom", <<7::256>>, <<8::64>>]]] ])
      %ExWire.Packet.Capability.Eth.BlockBodies{
        blocks: [
          %ExWire.Struct.Block{
            transactions_rlp: [[<<5>>, <<6>>, <<7>>, <<1::160>>, <<8>>, "hi", <<27>>, <<9>>, <<10>>]],
            transactions: [%Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1::160>>, value: 8, v: 27, r: 9, s: 10, data: "hi"}],
            ommers_rlp: [[<<1::256>>, <<2::256>>, <<3::160>>, <<4::256>>, <<5::256>>, <<6::256>>, <<>>, <<5>>, <<1>>, <<5>>, <<3>>, <<6>>, "Hi mom", <<7::256>>, <<8::64>>]],
            ommers: [%Block.Header{parent_hash: <<1::256>>, ommers_hash: <<2::256>>, beneficiary: <<3::160>>, state_root: <<4::256>>, transactions_root: <<5::256>>, receipts_root: <<6::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<7::256>>, nonce: <<8::64>>}]
          },
          %ExWire.Struct.Block{
            transactions_rlp: [[<<6>>, <<6>>, <<7>>, <<1::160>>, <<8>>, "hi", <<27>>, <<9>>, <<10>>]],
            transactions: [%Blockchain.Transaction{nonce: 6, gas_price: 6, gas_limit: 7, to: <<1::160>>, value: 8, v: 27, r: 9, s: 10, data: "hi"}],
            ommers_rlp: [[<<1::256>>, <<2::256>>, <<3::160>>, <<4::256>>, <<5::256>>, <<6::256>>, <<>>, <<5>>, <<1>>, <<5>>, <<3>>, <<6>>, "Hi mom", <<7::256>>, <<8::64>>]],
            ommers: [%Block.Header{parent_hash: <<1::256>>, ommers_hash: <<2::256>>, beneficiary: <<3::160>>, state_root: <<4::256>>, transactions_root: <<5::256>>, receipts_root: <<6::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<7::256>>, nonce: <<8::64>>}]
          }
        ]
      }
  """
  @impl true
  @spec deserialize(ExRLP.t()) :: t
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

      iex> %ExWire.Packet.Capability.Eth.BlockBodies{blocks: []}
      ...> |> ExWire.Packet.Capability.Eth.BlockBodies.handle()
      :ok
  """
  @impl true
  @spec handle(ExWire.Packet.packet()) :: ExWire.Packet.handle_response()
  def handle(packet = %__MODULE__{}) do
    :ok = Logger.info("[Packet] Peer sent #{Enum.count(packet.blocks)} block(s).")

    :ok
  end
end
