defmodule ExWire.Packet.Capability.Par.SnapshotData do
  @moduledoc """
  Respond to a GetSnapshotData message with either an empty RLP list or a
  1-item RLP list containing the raw chunk data requested.

  ```
  `SnapshotData` [`0x14`, `chunk_data` or nothing]
  ```
  """
  alias ExthCrypto.Hash.Keccak
  alias ExWire.Packet.Capability.Par.SnapshotData.{BlockChunk, StateChunk}
  require Logger

  @behaviour ExWire.Packet

  @type t :: %__MODULE__{
          hash: EVM.hash(),
          chunk: BlockChunk.t() | StateChunk.t() | nil
        }

  defstruct [:hash, :chunk]

  @doc """
  Returns the relative message id offset for this message.
  This will help determine what its message ID is relative to other Packets in the same Capability.
  """
  @impl true
  @spec message_id_offset() :: 0x14
  def message_id_offset do
    0x14
  end

  @doc """
  Given a SnapshotData packet, serializes for transport over Eth Wire Protocol.

  ## Examples

      iex> %ExWire.Packet.Capability.Par.SnapshotData{
      ...>   chunk: %ExWire.Packet.Capability.Par.SnapshotData.BlockChunk{
      ...>     number: 5,
      ...>     hash: <<6::256>>,
      ...>     total_difficulty: 7,
      ...>     block_data_list: []
      ...>    }
      ...> }
      ...> |> ExWire.Packet.Capability.Par.SnapshotData.serialize()
      [<<36, 12, 227, 5, 160, 0, 118, 1, 0, 4, 6, 7>>]

      iex> %ExWire.Packet.Capability.Par.SnapshotData{
      ...>   chunk: %ExWire.Packet.Capability.Par.SnapshotData.StateChunk{
      ...>     account_entries: [
      ...>       {
      ...>         <<1::256>>,
      ...>         %ExWire.Packet.Capability.Par.SnapshotData.StateChunk.RichAccount{
      ...>           nonce: 2,
      ...>           balance: 3,
      ...>           code_flag: :has_code,
      ...>           code: <<5::256>>,
      ...>           storage: [{<<1::256>>, <<2::256>>}]
      ...>         }
      ...>       }
      ...>     ]
      ...>   }
      ...> }
      ...> |> ExWire.Packet.Capability.Par.SnapshotData.serialize()
      [<<145, 1, 20, 248, 143, 248, 141, 160, 0, 118, 1, 0, 20, 1, 248, 106, 2, 3, 1, 126, 38, 0, 16, 5, 248, 68, 248, 66, 126, 37, 0, 130, 70, 0, 0, 2>>]
  """
  @impl true
  def serialize(%__MODULE__{chunk: chunk = %{__struct__: mod}}) do
    {:ok, res} =
      chunk
      |> mod.serialize()
      |> ExRLP.encode()
      |> :snappyer.compress()

    [res]
  end

  @doc """
  Given an RLP-encoded SnapshotData packet from Eth Wire Protocol,
  decodes into a SnapshotData struct.

  ## Examples

      iex> [<<36, 12, 227, 5, 160, 0, 118, 1, 0, 4, 6, 7>>]
      ...> |> ExWire.Packet.Capability.Par.SnapshotData.deserialize()
      %ExWire.Packet.Capability.Par.SnapshotData{
        chunk: %ExWire.Packet.Capability.Par.SnapshotData.BlockChunk{
          number: 5,
          hash: <<6::256>>,
          total_difficulty: 7,
          block_data_list: []
         },
         hash: <<221, 170, 108, 39, 117, 113, 13, 3, 231, 40, 69, 49, 126, 6,
                 109, 164, 92, 237, 157, 243, 181, 196, 88, 128, 192, 177, 109,
                 36, 77, 236, 86, 196>>
      }

      iex> [<<145, 1, 20, 248, 143, 248, 141, 160, 0, 118, 1, 0, 20, 1, 248,
      ...>    106, 2, 3, 1, 126, 38, 0, 16, 5, 248, 68, 248, 66, 126, 37, 0,
      ...>    130, 70, 0, 0, 2>>]
      ...> |> ExWire.Packet.Capability.Par.SnapshotData.deserialize()
      %ExWire.Packet.Capability.Par.SnapshotData{
        chunk: %ExWire.Packet.Capability.Par.SnapshotData.StateChunk{
          account_entries: [
            {
              <<1::256>>,
              %ExWire.Packet.Capability.Par.SnapshotData.StateChunk.RichAccount{
                nonce: 2,
                balance: 3,
                code_flag: :has_code,
                code: <<5::256>>,
                storage: [{<<1::256>>, <<2::256>>}]
              }
            }
          ]
        },
        hash: <<8, 203, 227, 135, 24, 92, 98, 193, 28, 230, 1, 177, 51, 95,
                135, 13, 223, 76, 129, 212, 190, 45, 44, 204, 198, 38, 249,
                186, 174, 18, 121, 52>>
      }
  """
  @impl true
  def deserialize(rlp) do
    [chunk_data] = rlp

    hash = Keccak.kec(chunk_data)

    {:ok, chunk_rlp_encoded} = :snappyer.decompress(chunk_data)

    chunk_rlp = ExRLP.decode(chunk_rlp_encoded)

    # Quick way to determine if chunk is a block chunk or state chunk is that
    # state chunks start with a list element where block chunks do not.
    chunk =
      case chunk_rlp do
        [] ->
          nil

        [el | _rest] when is_list(el) ->
          StateChunk.deserialize(chunk_rlp)

        _ ->
          BlockChunk.deserialize(chunk_rlp)
      end

    %__MODULE__{chunk: chunk, hash: hash}
  end

  @doc """
  Handles a SnapshotData message. We should send our manifest
  to the peer. For now, we'll do nothing.

  ## Examples

      iex> %ExWire.Packet.Capability.Par.SnapshotData{}
      ...> |> ExWire.Packet.Capability.Par.SnapshotData.handle()
      :ok
  """
  @impl true
  def handle(_packet = %__MODULE__{}) do
    :ok
  end
end
