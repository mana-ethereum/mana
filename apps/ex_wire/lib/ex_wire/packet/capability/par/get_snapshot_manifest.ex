defmodule ExWire.Packet.Capability.Par.GetSnapshotManifest do
  @moduledoc """
  Request a snapshot manifest in RLP form from a peer.

  ```
  `GetSnapshotManifest` [`0x11`]
  ```
  """

  @behaviour ExWire.Packet

  @type t :: %__MODULE__{}

  defstruct []

  @doc """
  Returns the relative message id offset for this message.
  This will help determine what its message ID is relative to other Packets in the same Capability.
  """
  @impl true
  @spec message_id_offset() :: 0x11
  def message_id_offset do
    0x11
  end

  @doc """
  Given a GetSnapshotManifest packet, serializes for transport over Eth Wire Protocol.

  ## Examples

      iex> %ExWire.Packet.Capability.Par.GetSnapshotManifest{}
      ...> |> ExWire.Packet.Capability.Par.GetSnapshotManifest.serialize()
      []
  """
  @impl true
  def serialize(_packet = %__MODULE__{}) do
    []
  end

  @doc """
  Given an RLP-encoded GetSnapshotManifest packet from Eth Wire Protocol,
  decodes into a GetSnapshotManifest struct.

  ## Examples

      iex> ExWire.Packet.Capability.Par.GetSnapshotManifest.deserialize([])
      %ExWire.Packet.Capability.Par.GetSnapshotManifest{}
  """
  @impl true
  def deserialize(rlp) do
    [] = rlp

    %__MODULE__{}
  end

  @doc """
  Handles a GetSnapshotManifest message. We should send our manifest
  to the peer. For now, we'll do nothing.

  ## Examples

      iex> %ExWire.Packet.Capability.Par.GetSnapshotManifest{}
      ...> |> ExWire.Packet.Capability.Par.GetSnapshotManifest.handle()
      :ok
  """
  @impl true
  def handle(_packet = %__MODULE__{}) do
    :ok
  end
end
