defmodule ExWire.Packet.Capability.Par.GetSnapshotData do
  @moduledoc """
  Request a chunk (identified by the given hash) from a peer.

  ```
  `GetSnapshotData` [`0x13`, `chunk_hash`: B_32]
  ```
  """

  @behaviour ExWire.Packet

  @type t :: %__MODULE__{
          chunk_hash: EVM.hash()
        }

  defstruct [
    :chunk_hash
  ]

  @doc """
  Returns the relative message id offset for this message.
  This will help determine what its message ID is relative to other Packets in the same Capability.
  """
  @impl true
  @spec message_id_offset() :: 0x13
  def message_id_offset do
    0x13
  end

  @doc """
  Given a GetSnapshotData packet, serializes for transport over Eth Wire Protocol.

  ## Examples

      iex> %ExWire.Packet.Capability.Par.GetSnapshotData{chunk_hash: <<1::256>>}
      ...> |> ExWire.Packet.Capability.Par.GetSnapshotData.serialize()
      [<<1::256>>]
  """
  @impl true
  def serialize(%__MODULE__{chunk_hash: chunk_hash}) do
    [
      chunk_hash
    ]
  end

  @doc """
  Given an RLP-encoded GetSnapshotData packet from Eth Wire Protocol,
  decodes into a GetSnapshotData struct.

  ## Examples

      iex> ExWire.Packet.Capability.Par.GetSnapshotData.deserialize([<<1::256>>])
      %ExWire.Packet.Capability.Par.GetSnapshotData{chunk_hash: <<1::256>>}
  """
  @impl true
  def deserialize(rlp) do
    [chunk_hash] = rlp

    %__MODULE__{chunk_hash: chunk_hash}
  end

  @doc """
  Handles a GetSnapshotData message. We should send our manifest
  to the peer. For now, we'll do nothing.

  ## Examples

      iex> %ExWire.Packet.Capability.Par.GetSnapshotData{}
      ...> |> ExWire.Packet.Capability.Par.GetSnapshotData.handle()
      :ok
  """
  @impl true
  def handle(_packet = %__MODULE__{}) do
    :ok
  end
end
