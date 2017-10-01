defmodule ExWire.Packet.Transactions do
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
  Given a Transactions packet, serializes for transport over Eth Wire Protocol.

  ## Examples

      iex> %ExWire.Packet.Transactions{
      ...>   transactions: [
      ...>     [1, 2, 3],
      ...>     [4, 5, 6]
      ...>   ]
      ...> }
      ...> |> ExWire.Packet.Transactions.serialize
      [ [1, 2, 3], [4, 5, 6] ]
  """
  @spec serialize(t) :: ExRLP.t
  def serialize(packet=%__MODULE__{}) do
    packet.transactions # TODO: Serialize accurately
  end

  @doc """
  Given an RLP-encoded Transactions packet from Eth Wire Protocol,
  decodes into a Tranasctions struct.

  ## Examples

      iex> ExWire.Packet.Transactions.deserialize([ [1, 2, 3], [4, 5, 6] ])
      %ExWire.Packet.Transactions{
        transactions: [
          [1, 2, 3],
          [4, 5, 6],
        ]
      }
  """
  @spec deserialize(ExRLP.t) :: t
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

      iex> %ExWire.Packet.Transactions{transactions: []}
      ...> |> ExWire.Packet.Transactions.handle()
      :ok
  """
  @spec handle(ExWire.Packet.packet) :: ExWire.Packet.handle_response
  def handle(packet=%__MODULE__{}) do
    # TODO: Do.
    Logger.debug("Peer sent #{Enum.count(packet.transactions)} transaction(s).")

    :ok
  end

end
