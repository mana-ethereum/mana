defmodule ExWire.Packet.Capability.Eth.Receipts do
  @moduledoc """
  TODO

  ```
  **Receipts** [`+0x10`, [`receipt_0`, `receipt_1`], ...]
  Provide a set of receipts which correspond to previously asked in
  `GetReceipts`.
  ```
  """
  require Logger

  alias Blockchain.Transaction.Receipt
  alias ExWire.Packet

  @behaviour Packet

  @type t :: %__MODULE__{
          receipts: list(Receipt.t())
        }

  defstruct receipts: []

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

  ## Examples

      iex> %ExWire.Packet.Capability.Eth.Receipts{receipts: [
      ...>   %Blockchain.Transaction.Receipt{state: <<1,2,3>>, cumulative_gas: 5, bloom_filter: <<2,3,4>>, logs: []}
      ...> ]}
      ...> |> ExWire.Packet.Capability.Eth.Receipts.serialize()
      [[<<1, 2, 3>>, 5, <<2, 3, 4>>, []]]
  """
  @impl true
  @spec serialize(t()) :: ExRLP.t()
  def serialize(packet = %__MODULE__{}) do
    Enum.map(packet.receipts, &Receipt.serialize/1)
  end

  @doc """
  Given an RLP-encoded Receipts packet from Eth Wire Protocol,
  decodes into a Receipts struct.

  ## Examples

      iex> ExWire.Packet.Capability.Eth.Receipts.deserialize([[<<1, 2, 3>>, 5, <<2, 3, 4>>, []]])
      %ExWire.Packet.Capability.Eth.Receipts{receipts: [
        %Blockchain.Transaction.Receipt{state: <<1,2,3>>, cumulative_gas: 5, bloom_filter: <<2,3,4>>, logs: []}
      ]}
  """
  @impl true
  @spec deserialize(ExRLP.t()) :: t()
  def deserialize(rlp) do
    receipts_rlp = rlp

    %__MODULE__{
      receipts: Enum.map(receipts_rlp, &Receipt.deserialize/1)
    }
  end

  @doc """
  Handles a Receipts message. We do not respond.

  ## Examples

      iex> %ExWire.Packet.Capability.Eth.Receipts{receipts: []}
      ...> |> ExWire.Packet.Capability.Eth.Receipts.handle()
      :ok
  """
  @impl true
  @spec handle(t()) :: ExWire.Packet.handle_response()
  def handle(_packet = %__MODULE__{}) do
    :ok
  end
end
