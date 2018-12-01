defmodule ExWire.Packet.Capability.Par.WarpStatus do
  @moduledoc """
  Status messages updated to handle warp details.

  ```
  **Status** [`+0x00`: `P`, `protocolVersion`: `P`, `networkId`: `P`,
              `td`: `P`, `bestHash`: `B_32`, `genesisHash`: `B_32`,
              `snapshot_hash`: B_32, `snapshot_number`: P]

  In addition to all the fields in eth protocol version 63’s status (denoted
  by `...`), include `snapshot_hash` and `snapshot_number` which signify the
  snapshot manifest RLP hash and block number respectively of the peer's local
  snapshot.
  ```
  """

  require Logger

  @behaviour ExWire.Packet

  @type t :: %__MODULE__{
          protocol_version: integer(),
          network_id: integer(),
          total_difficulty: integer(),
          best_hash: binary(),
          genesis_hash: binary(),
          snapshot_hash: EVM.hash(),
          snapshot_number: integer()
        }

  defstruct [
    :protocol_version,
    :network_id,
    :total_difficulty,
    :best_hash,
    :genesis_hash,
    :snapshot_hash,
    :snapshot_number
  ]

  @doc """
  Build a WarpStatus packet

  Note: we are currently reflecting values based on the packet received, but
  that should not be the case. We should provide the total difficulty of the
  best chain found in the block header, the best hash, and the genesis hash of
  our blockchain.

  TODO: Don't parrot the same data back to sender
  """
  @spec new(t()) :: t()
  def new(packet) do
    %__MODULE__{
      protocol_version: 1,
      network_id: ExWire.Config.chain().params.network_id,
      total_difficulty: packet.total_difficulty,
      best_hash: packet.genesis_hash,
      genesis_hash: packet.genesis_hash,
      snapshot_hash: <<0::256>>,
      snapshot_number: 0
    }
  end

  @doc """
  Returns the relative message id offset for this message.
  This will help determine what its message ID is relative to other Packets in the same Capability.
  """
  @impl true
  @spec message_id_offset() :: 0x00
  def message_id_offset do
    0x00
  end

  @doc """
  Given a WarpStatus packet, serializes for transport over Eth Wire Protocol.

  ## Examples

      iex> %ExWire.Packet.Capability.Par.WarpStatus{
      ...>   protocol_version: 0x63,
      ...>   network_id: 3,
      ...>   total_difficulty: 10,
      ...>   best_hash: <<5>>,
      ...>   genesis_hash: <<6::256>>,
      ...>   snapshot_hash: <<7::256>>,
      ...>   snapshot_number: 8,
      ...> }
      ...> |> ExWire.Packet.Capability.Par.WarpStatus.serialize
      [0x63, 3, 10, <<5>>, <<6::256>>, <<7::256>>, 8]
  """
  @impl true
  def serialize(packet = %__MODULE__{}) do
    [
      packet.protocol_version,
      packet.network_id,
      packet.total_difficulty,
      packet.best_hash,
      packet.genesis_hash,
      packet.snapshot_hash,
      packet.snapshot_number
    ]
  end

  @doc """
  Given an RLP-encoded Status packet from Eth Wire Protocol, decodes into a
  Status packet.

  ## Examples

      iex> ExWire.Packet.Capability.Par.WarpStatus.deserialize([<<0x63>>, <<3>>, <<10>>, <<5>>, <<6::256>>, <<7::256>>, 8])
      %ExWire.Packet.Capability.Par.WarpStatus{
        protocol_version: 0x63,
        network_id: 3,
        total_difficulty: 10,
        best_hash: <<5>>,
        genesis_hash: <<6::256>>,
        snapshot_hash: <<7::256>>,
        snapshot_number: 8,
      }
  """
  @impl true
  def deserialize(rlp) do
    [
      protocol_version,
      network_id,
      total_difficulty,
      best_hash,
      genesis_hash,
      snapshot_hash,
      snapshot_number
    ] = rlp

    %__MODULE__{
      protocol_version: :binary.decode_unsigned(protocol_version),
      network_id: :binary.decode_unsigned(network_id),
      total_difficulty: :binary.decode_unsigned(total_difficulty),
      best_hash: best_hash,
      genesis_hash: genesis_hash,
      snapshot_hash: snapshot_hash,
      snapshot_number: snapshot_number
    }
  end

  @doc """
  Handles a WarpStatus message.

  We should decide whether or not we want to continue communicating with
  this peer. E.g. do our network and protocol versions match?

  ## Examples

      iex> %ExWire.Packet.Capability.Par.WarpStatus{
      ...>   protocol_version: 63,
      ...>   network_id: 3,
      ...>   total_difficulty: 10,
      ...>   best_hash: <<4::256>>,
      ...>   genesis_hash: <<4::256>>
      ...> }
      ...> |> ExWire.Packet.Capability.Par.WarpStatus.handle()
      {:send,
             %ExWire.Packet.Capability.Par.WarpStatus{
               best_hash: <<4::256>>,
               genesis_hash: <<4::256>>,
               network_id: 3,
               protocol_version: 1,
               total_difficulty: 10,
               snapshot_hash: <<0::256>>,
               snapshot_number: 0
             }}
  """
  @impl true
  def handle(packet = %__MODULE__{}) do
    Exth.trace(fn -> "[Packet] Got WarpStatus: #{inspect(packet)}" end)

    {:send, new(packet)}
  end
end
