defmodule ExWire.Packet.Capability.Par.GetNodeData do
  @moduledoc """
  Par Wire Packet for getting Node Data from a peer.

  ```
  **GetNodeData** [+0x0d, hash_0: B_32, hash_1: B_32, ...]

  Require peer to return a NodeData message.
  Hint that useful values in it are those which correspond to given hashes.
  ```
  """

  require Logger

  @behaviour ExWire.Packet

  @type t :: %__MODULE__{
          hashes: [binary()]
        }

  defstruct [
    :hashes
  ]

  @spec new([binary()]) :: t()
  def new(hashes) do
    %__MODULE__{
      hashes: hashes
    }
  end

  @doc """
  Returns the relative message id offset for this message.
  This will help determine what its message ID is relative to other Packets in the same Capability.
  """
  @impl true
  @spec message_id_offset() :: 0x0D
  def message_id_offset do
    0x0D
  end

  @doc """
  Given a GetNodeData packet, serializes for transport over Eth Wire Protocol.
  """
  @impl true
  @spec serialize(t) :: ExRLP.t()
  def serialize(packet = %__MODULE__{}) do
    for hash <- packet.hashes, do: hash
  end

  @doc """
  Given an RLP-encoded GetNodeData packet from Eth Wire Protocol, decodes into
  a `GetNodeData` struct.
  """
  @impl true
  @spec deserialize(ExRLP.t()) :: t
  def deserialize(rlp) do
    hashes = for hash <- rlp, do: hash

    new(hashes)
  end

  @doc """
  Handles a GetNodeData message.

  ## Examples

      iex> ExWire.Packet.Capability.Par.GetNodeData.new([])
      ...> |> ExWire.Packet.Capability.Par.GetNodeData.handle()
      :ok
  """
  @impl true
  @spec handle(ExWire.Packet.packet()) :: ExWire.Packet.handle_response()
  def handle(packet = %__MODULE__{}) do
    :ok = Logger.info("[Packet] Peer sent #{Enum.count(packet.hashes)} node hash(es).")

    :ok
  end
end
