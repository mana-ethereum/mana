defmodule ExWire.Packet.Capability.Eth.Receipts do
  @moduledoc """
  Eth Wire Packet for getting Receipts from a peer.

  ```
  **Receipts** [+0x0e, value_0: B, value_1: B, ...]
  Provide a set of values which correspond to previously asked node data hashes from GetReceipts.
  Does not need to contain all; best effort is fine.
  If it contains none, then has no information for previous GetReceipts hashes.
  ```
  """

  require Logger
  alias Blockchain.Transaction.Receipt

  @behaviour ExWire.Packet

  @type t :: %__MODULE__{
          receipts: [[Receipt.t()]]
        }

  defstruct [
    :receipts
  ]

  @spec new([[Receipt.t()]]) :: t()
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
    for receipts <- packet.receipts do
      for receipt <- receipts do
        Receipt.serialize(receipt)
      end
    end
  end

  @doc """
  Given an RLP-encoded Receipts packet from Eth Wire Protocol, decodes into
  a `Receipts` struct.
  """
  @impl true
  @spec deserialize(ExRLP.t()) :: t
  def deserialize(rlp) do
    block_receipts =
      for receipts <- rlp do
        for receipt <- receipts do
          Receipt.deserialize(receipt)
        end
      end

    new(block_receipts)
  end

  @doc """
  Handles a Receipts message.

  ## Examples

      iex> ExWire.Packet.Capability.Eth.Receipts.new([])
      ...> |> ExWire.Packet.Capability.Eth.Receipts.handle()
      :ok
  """
  @impl true
  @spec handle(ExWire.Packet.packet()) :: ExWire.Packet.handle_response()
  def handle(packet = %__MODULE__{}) do
    :ok = Logger.info("[Packet] Peer sent #{Enum.count(packet.receipts)} Receipt(s).")

    :ok
  end
end
