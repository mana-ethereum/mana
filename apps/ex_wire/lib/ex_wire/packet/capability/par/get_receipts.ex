defmodule ExWire.Packet.Capability.Par.GetReceipts do
  @moduledoc """
  Par Wire Packet for getting Receipts from a peer.

  ```
  **GetReceipts** [+0x0f, hash_0: B_32, hash_1: B_32, ...]
  Require peer to return a Receipts message.
  Hint that useful values in it are those which correspond to blocks of the given hashes.
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
  @spec message_id_offset() :: 0x0F
  def message_id_offset do
    0x0F
  end

  @doc """
  Given a Receipts packet, serializes for transport over Eth Wire Protocol.
  """
  @impl true
  @spec serialize(t) :: ExRLP.t()
  def serialize(packet = %__MODULE__{}) do
    for hash <- packet.hashes, do: hash
  end

  @doc """
  Given an RLP-encoded Receipts packet from Eth Wire Protocol, decodes into
  a `Receipts` struct.
  """
  @impl true
  @spec deserialize(ExRLP.t()) :: t
  def deserialize(rlp) do
    hashes = for hash <- rlp, do: hash

    new(hashes)
  end

  @doc """
  Handles a Receipts message.

  ## Examples

      iex> ExWire.Packet.Capability.Par.Receipts.new([])
      ...> |> ExWire.Packet.Capability.Par.Receipts.handle()
      :ok
  """
  @impl true
  @spec handle(ExWire.Packet.packet()) :: ExWire.Packet.handle_response()
  def handle(packet = %__MODULE__{}) do
    :ok = Logger.info("[Packet] Peer sent #{Enum.count(packet.hashes)} Receipt(s).")

    :ok
  end
end
