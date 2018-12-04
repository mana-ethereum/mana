defmodule ExWire.Packet.Capability.Eth.GetReceipts do
  @moduledoc """
  TODO

  ```
  **GetReceipts** [`+0x0d`, `hash_0`: `B_32`, `hash_1`: `B_32`, `...`]
  Require peer to return a `Receipts` message. Hint that useful values in it
  are those which correspond to blocks of the given hashes.
  ```
  """
  require Logger

  alias Blockchain.Transaction.Receipt
  alias ExWire.Bridge.Sync
  alias ExWire.Packet
  alias ExWire.Packet.Capability.Eth.Receipts
  alias MerklePatriciaTree.TrieStorage

  @behaviour Packet

  @sync Application.get_env(:ex_wire, :sync_mock, Sync)
  @max_hashes_supported 100

  @type t :: %__MODULE__{
          hashes: list(EVM.hash())
        }

  defstruct hashes: []

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
  Given a GetReceipts packet, serializes for transport over Eth Wire Protocol.

  ## Examples

      iex> %ExWire.Packet.Capability.Eth.GetReceipts{hashes: [<<1::256>>, <<2::256>>]}
      ...> |> ExWire.Packet.Capability.Eth.GetReceipts.serialize()
      [<<1::256>>, <<2::256>>]
  """
  @impl true
  @spec serialize(t()) :: ExRLP.t()
  def serialize(packet = %__MODULE__{}) do
    packet.hashes
  end

  @doc """
  Given an RLP-encoded GetReceipts packet from Eth Wire Protocol,
  decodes into a GetReceipts struct.

  ## Examples

      iex> ExWire.Packet.Capability.Eth.GetReceipts.deserialize([<<1::256>>, <<2::256>>])
      %ExWire.Packet.Capability.Eth.GetReceipts{hashes: [<<1::256>>, <<2::256>>]}
  """
  @impl true
  @spec deserialize(ExRLP.t()) :: t()
  def deserialize(rlp) do
    hashes = rlp

    %__MODULE__{
      hashes: hashes
    }
  end

  @doc """
  Handles a GetReceipts message. We should send the node data for the given
  keys if we have that data.
  """
  @impl true
  @spec handle(t()) :: ExWire.Packet.handle_response()
  def handle(packet = %__MODULE__{}) do
    receipts =
      case @sync.get_current_trie() do
        {:ok, trie} ->
          get_receipts(
            trie,
            Enum.take(packet.hashes, @max_hashes_supported)
          )

        {:error, error} ->
          :ok =
            Logger.warn(fn ->
              "#{__MODULE__} Error calling Sync.get_current_trie(): #{error}. Returning empty receipts."
            end)

          []
      end

    {:send, %Receipts{receipts: receipts}}
  end

  @spec get_receipts(Trie.t(), list(EVM.hash())) :: list(Receipt.t())
  defp get_receipts(trie, hashes) do
    do_get_receipts(trie, hashes, [])
  end

  @spec do_get_receipts(Trie.t(), list(EVM.hash()), list(Receipt.t())) :: list(Receipt.t())
  defp do_get_receipts(_trie, [], acc_receipts), do: Enum.reverse(acc_receipts)

  defp do_get_receipts(trie, [hash | rest_hashes], acc_receipts) do
    # TODO: Get receipts correctly or whatever.
    new_acc =
      case TrieStorage.get_raw_key(trie, hash) do
        :not_found ->
          acc_receipts

        {:ok, receipt_rlp_bin} ->
          receipt =
            receipt_rlp_bin
            |> ExRLP.decode()
            |> Receipt.deserialize()

          [receipt | acc_receipts]
      end

    do_get_receipts(trie, rest_hashes, new_acc)
  end
end
