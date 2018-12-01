defmodule ExWire.Packet.Capability.Par.SnapshotManifest do
  @moduledoc """
  Respond to a GetSnapshotManifest message with either an empty RLP list or a
  1-item RLP list containing a snapshot manifest

  ```
  `SnapshotManifest` [`0x12`, `manifest` or nothing]
  ```
  """
  import Exth, only: [maybe_decode_unsigned: 1]

  @behaviour ExWire.Packet

  defmodule Manifest do
    @moduledoc """
    A Manifest from a warp-sync peer.

    version: snapshot format version. Must be set to 2.
    state_hashes: a list of all the state chunks in this snapshot
    block_hashes: a list of all the block chunks in this snapshot
    state_root: the root which the rebuilt state trie should have. Used to ensure validity
    block_number: the number of the best block in the snapshot; the one which the state coordinates to.
    block_hash: the best block in the snapshot's hash.
    """

    defstruct [
      :version,
      :state_hashes,
      :block_hashes,
      :state_root,
      :block_number,
      :block_hash
    ]
  end

  @type manifest :: %Manifest{
          version: integer(),
          state_hashes: list(EVM.hash()),
          block_hashes: list(EVM.hash()),
          state_root: binary(),
          block_number: integer(),
          block_hash: EVM.hash()
        }

  @type t :: %__MODULE__{
          manifest: manifest() | nil
        }

  defstruct manifest: nil

  @doc """
  Returns the relative message id offset for this message.
  This will help determine what its message ID is relative to other Packets in the same Capability.
  """
  @impl true
  @spec message_id_offset() :: 0x12
  def message_id_offset do
    0x12
  end

  @doc """
  Given a SnapshotManifest packet, serializes for transport over Eth Wire Protocol.

  ## Examples

      iex> %ExWire.Packet.Capability.Par.SnapshotManifest{manifest: nil}
      ...> |> ExWire.Packet.Capability.Par.SnapshotManifest.serialize()
      []

      iex> %ExWire.Packet.Capability.Par.SnapshotManifest{
      ...>   manifest: %ExWire.Packet.Capability.Par.SnapshotManifest.Manifest{
      ...>     version: 2,
      ...>     state_hashes: [<<1::256>>, <<2::256>>],
      ...>     block_hashes: [<<3::256>>, <<4::256>>],
      ...>     state_root: <<5::256>>,
      ...>     block_number: 6,
      ...>     block_hash: <<7::256>>
      ...>   }
      ...> }
      ...> |> ExWire.Packet.Capability.Par.SnapshotManifest.serialize()
      [2, [<<1::256>>, <<2::256>>], [<<3::256>>, <<4::256>>], <<5::256>>, 6, <<7::256>>]
  """
  @impl true
  def serialize(_packet = %__MODULE__{manifest: nil}), do: []

  def serialize(_packet = %__MODULE__{manifest: manifest}) do
    [
      manifest.version,
      manifest.state_hashes,
      manifest.block_hashes,
      manifest.state_root,
      manifest.block_number,
      manifest.block_hash
    ]
  end

  @doc """
  Given an RLP-encoded SnapshotManifest packet from Eth Wire Protocol,
  decodes into a SnapshotManifest struct.

  ## Examples

      iex> ExWire.Packet.Capability.Par.SnapshotManifest.deserialize([])
      %ExWire.Packet.Capability.Par.SnapshotManifest{manifest: nil}

      iex> ExWire.Packet.Capability.Par.SnapshotManifest.deserialize([[2, [<<1::256>>, <<2::256>>], [<<3::256>>, <<4::256>>], <<5::256>>, 6, <<7::256>>]])
      %ExWire.Packet.Capability.Par.SnapshotManifest{
        manifest: %ExWire.Packet.Capability.Par.SnapshotManifest.Manifest{
          version: 2,
          state_hashes: [<<1::256>>, <<2::256>>],
          block_hashes: [<<3::256>>, <<4::256>>],
          state_root: <<5::256>>,
          block_number: 6,
          block_hash: <<7::256>>
        }
      }

      iex> ExWire.Packet.Capability.Par.SnapshotManifest.deserialize([[3, [<<1::256>>, <<2::256>>], [<<3::256>>, <<4::256>>], <<5::256>>, 6, <<7::256>>]])
      ** (MatchError) no match of right hand side value: 3
  """
  @impl true
  def deserialize([]), do: %__MODULE__{manifest: nil}

  def deserialize([rlp]) do
    [
      version,
      state_hashes,
      block_hashes,
      state_root,
      block_number,
      block_hash
    ] = rlp

    %__MODULE__{
      manifest: %Manifest{
        version: 2 = maybe_decode_unsigned(version),
        state_hashes: state_hashes,
        block_hashes: block_hashes,
        state_root: state_root,
        block_number: maybe_decode_unsigned(block_number),
        block_hash: block_hash
      }
    }
  end

  @doc """
  Handles a SnapshotManifest message. We should send our manifest
  to the peer. For now, we'll do nothing.

  ## Examples

      iex> %ExWire.Packet.Capability.Par.SnapshotManifest{}
      ...> |> ExWire.Packet.Capability.Par.SnapshotManifest.handle()
      :ok
  """
  @impl true
  def handle(_packet = %__MODULE__{}) do
    # TODO: Respond with empty manifest
    :ok
  end
end
