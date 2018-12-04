defmodule ExWire.Packet.Capability.Eth.GetNodeData do
  @moduledoc """
  TODO

  ```
  **GetNodeData** [`+0x0d`, `hash_0`: `B_32`, `hash_1`: `B_32`, `...`]
  Require peer to return a NodeData message. Hint that useful values in it are those which correspond to given hashes.
  ```
  """

  alias ExWire.Bridge.Sync
  alias ExWire.Packet
  alias ExWire.Packet.Capability.Eth.NodeData
  alias MerklePatriciaTree.TrieStorage
  require Logger

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
  Given a GetNodeData packet, serializes for transport over Eth Wire Protocol.

  ## Examples

      iex> %ExWire.Packet.Capability.Eth.GetNodeData{hashes: [<<1::256>>, <<2::256>>]}
      ...> |> ExWire.Packet.Capability.Eth.GetNodeData.serialize()
      [<<1::256>>, <<2::256>>]
  """
  @impl true
  @spec serialize(t()) :: ExRLP.t()
  def serialize(packet = %__MODULE__{}) do
    packet.hashes
  end

  @doc """
  Given an RLP-encoded GetNodeData packet from Eth Wire Protocol,
  decodes into a GetNodeData struct.

  ## Examples

      iex> ExWire.Packet.Capability.Eth.GetNodeData.deserialize([<<1::256>>, <<2::256>>])
      %ExWire.Packet.Capability.Eth.GetNodeData{hashes: [<<1::256>>, <<2::256>>]}
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
  Handles a GetNodeData message. We should send the node data for the given
  keys if we have that data.
  """
  @impl true
  @spec handle(t()) :: ExWire.Packet.handle_response()
  def handle(packet = %__MODULE__{}) do
    values =
      case @sync.get_current_trie() do
        {:ok, trie} ->
          get_node_data(
            trie,
            Enum.take(packet.hashes, @max_hashes_supported)
          )

        {:error, error} ->
          :ok =
            Logger.warn(fn ->
              "#{__MODULE__} Error calling Sync.get_current_trie(): #{error}. Returning empty values."
            end)

          []
      end

    {:send, %NodeData{values: values}}
  end

  @spec get_node_data(Trie.t(), list(EVM.hash())) :: list(binary())
  defp get_node_data(trie, hashes) do
    do_get_node_data(trie, hashes, [])
  end

  @spec do_get_node_data(Trie.t(), list(EVM.hash()), list(binary())) :: list(binary())
  defp do_get_node_data(_trie, [], acc_values), do: Enum.reverse(acc_values)

  defp do_get_node_data(trie, [hash | rest_hashes], acc_values) do
    new_acc =
      case TrieStorage.get_raw_key(trie, hash) do
        :not_found ->
          acc_values

        {:ok, value} ->
          [value | acc_values]
      end

    do_get_node_data(trie, rest_hashes, new_acc)
  end
end
