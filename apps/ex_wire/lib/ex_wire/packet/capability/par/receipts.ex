defmodule ExWire.Packet.Capability.Par.Receipts do
  @moduledoc """
  Par Wire Packet for getting Receipts from a peer.

  ```
  **Receipts** [+0x0e, value_0: B, value_1: B, ...]
  Provide a set of values which correspond to previously asked node data hashes from GetReceipts.
  Does not need to contain all; best effort is fine.
  If it contains none, then has no information for previous GetReceipts hashes.
  ```
  """

  require Logger

  @behaviour ExWire.Packet

  @type t :: %__MODULE__{
          receipts: [any()]
        }

  defstruct [
    :receipts
  ]

  @spec new([any()]) :: t()
  def new(receipts) do
    %__MODULE__{
      receipts: receipts
    }
  end

  @doc """
  Returns the relative message id offset for this message.
  This will help determine what its message ID is relative to other Packets in the same Capability.
  """
  @impl true
  @spec message_id_offset() :: 0x10
  def message_id_offset do
    0x10
  end

  @doc """
  Given a Receipts packet, serializes for transport over Eth Wire Protocol.
  """
  @impl true
  @spec serialize(t) :: ExRLP.t()
  def serialize(packet = %__MODULE__{}) do
    for receipt <- packet.receipts, do: receipt
  end

  @doc """
  Given an RLP-encoded Receipts packet from Eth Wire Protocol, decodes into
  a `Receipts` struct.
  """
  @impl true
  @spec deserialize(ExRLP.t()) :: t
  def deserialize(rlp) do
    receipts = for receipt <- rlp, do: receipt

    new(receipts)
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
    :ok = Logger.info("[Packet] Peer sent #{Enum.count(packet.receipts)} Receipt(s).")

    :ok
  end
end
