defmodule ExWire.Packet.Capability.Par.GetBlockBodies do
  @moduledoc """
  Request the bodies for a set of blocks by hash.

  ```
  `GetBlockBodies` [`+0x05`, `hash_0`: `B_32`, `hash_1`: `B_32`, ...]

  Require peer to return a BlockBodies message. Specify the set of blocks that
  we're interested in with the hashes.
  ```
  """

  @behaviour ExWire.Packet

  alias Blockchain.Block, as: BlockchainBlock
  alias ExWire.Bridge.Sync
  alias ExWire.Packet.Capability.Par.BlockBodies
  alias ExWire.Struct.Block
  require Logger

  @sync Application.get_env(:ex_wire, :sync_mock, Sync)

  @type t :: %__MODULE__{
          hashes: [binary()]
        }

  defstruct hashes: []

  @doc """
  Returns the relative message id offset for this message.
  This will help determine what its message ID is relative to other Packets in the same Capability.
  """
  @impl true
  @spec message_id_offset() :: 5
  def message_id_offset do
    0x05
  end

  @doc """
  Given a GetBlockBodies packet, serializes for transport over Eth Wire Protocol.

  ## Examples

      iex> %ExWire.Packet.Capability.Par.GetBlockBodies{hashes: [<<5>>, <<6>>]}
      ...> |> ExWire.Packet.Capability.Par.GetBlockBodies.serialize
      [<<5>>, <<6>>]
  """
  @impl true
  @spec serialize(t) :: ExRLP.t()
  def serialize(packet = %__MODULE__{}) do
    packet.hashes
  end

  @doc """
  Given an RLP-encoded GetBlockBodies packet from Eth Wire Protocol,
  decodes into a GetBlockBodies struct.

  ## Examples

      iex> ExWire.Packet.Capability.Par.GetBlockBodies.deserialize([<<5>>, <<6>>])
      %ExWire.Packet.Capability.Par.GetBlockBodies{hashes: [<<5>>, <<6>>]}
  """
  @impl true
  @spec deserialize(ExRLP.t()) :: t
  def deserialize(rlp) do
    # verify it's a list
    hashes = [_h | _t] = rlp

    %__MODULE__{
      hashes: hashes
    }
  end

  @doc """
  Handles a GetBlockBodies message. We should send the block bodies
  to the peer if we have them. For now, we'll do nothing.
  """
  @impl true
  @spec handle(ExWire.Packet.packet()) :: ExWire.Packet.handle_response()
  def handle(packet = %__MODULE__{}) do
    bodies =
      case @sync.get_current_trie() do
        {:ok, trie} ->
          get_block_bodies(trie, packet.hashes)

        {:error, error} ->
          _ =
            Logger.debug(fn ->
              "Error calling Sync.get_current_trie(): #{error}. Returning empty headers."
            end)

          []
      end

    {:send, BlockBodies.new(bodies)}
  end

  defp get_block_bodies(trie, hashes) do
    hashes
    |> Stream.map(fn hash ->
      case BlockchainBlock.get_block(hash, trie) do
        {:ok, block} ->
          Block.new(block)

        :not_found ->
          nil
      end
    end)
    |> Stream.reject(&is_nil/1)
    |> Enum.to_list()
  end
end
