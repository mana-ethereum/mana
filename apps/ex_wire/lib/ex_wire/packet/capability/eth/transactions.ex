defmodule ExWire.Packet.Capability.Eth.Transactions do
  @moduledoc """
  Eth Wire Packet for communicating new transactions.

  ```
  **Transactions** [`+0x02`: `P`, [`nonce`: `P`, `receivingAddress`: `B_20`, `value`: `P`, ...], ...]

  Specify (a) transaction(s) that the peer should make sure is included on
  its transaction queue. The items in the list (following the first item 0x12)
  are transactions in the format described in the main Ethereum specification.
  Nodes must not resend the same transaction to a peer in the same session. This
  packet must contain at least one (new) transaction.
  ```
  """

  require Logger

  @behaviour ExWire.Packet

  @type t :: %__MODULE__{
          transactions: [any()]
        }

  defstruct [
    :transactions
  ]

  @doc """
  Returns the relative message id offset for this message.
  This will help determine what its message ID is relative to other Packets in the same Capability.
  """
  @impl true
  @spec message_id_offset() :: 2
  def message_id_offset do
    0x02
  end

  @doc """
  Given a Transactions packet, serializes for transport over Eth Wire Protocol.

  ## Examples

      iex> %ExWire.Packet.Capability.Eth.Transactions{
      ...>   transactions: [
      ...>     [1, 2, 3],
      ...>     [4, 5, 6]
      ...>   ]
      ...> }
      ...> |> ExWire.Packet.Capability.Eth.Transactions.serialize
      [ [1, 2, 3], [4, 5, 6] ]
  """
  @impl true
  @spec serialize(t) :: ExRLP.t()
  def serialize(packet = %__MODULE__{}) do
    # TODO: Serialize accurately
    packet.transactions
  end

  @doc """
  Given an RLP-encoded Transactions packet from Eth Wire Protocol,
  decodes into a Tranasctions struct.

  ## Examples

      iex> ExWire.Packet.Capability.Eth.Transactions.deserialize([ [1, 2, 3], [4, 5, 6] ])
      %ExWire.Packet.Capability.Eth.Transactions{
        transactions: [
          [1, 2, 3],
          [4, 5, 6],
        ]
      }
  """
  @impl true
  @spec deserialize(ExRLP.t()) :: t
  def deserialize(rlp) do
    # TODO: Deserialize from proper struct

    %__MODULE__{
      transactions: rlp
    }
  end

  @doc """
  Handles a Transactions message. We should try to add the transaction
  to a queue and process it. Or, right now, do nothing.

  ## Examples

      iex> %ExWire.Packet.Capability.Eth.Transactions{transactions: []}
      ...> |> ExWire.Packet.Capability.Eth.Transactions.handle()
      :ok
  """
  @impl true
  @spec handle(ExWire.Packet.packet()) :: :ok
  def handle(packet = %__MODULE__{}) do
    _ =
      Logger.debug(fn ->
        "[Packet] Peer sent #{Enum.count(packet.transactions)} transaction(s)."
      end)

    :ok
  end
end
