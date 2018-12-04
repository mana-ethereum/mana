defmodule ExWire.Packet.Capability.Eth.NodeData do
  @moduledoc """
  TODO

  ```
  **NodeData** [`+0x0e`, `value_0`: `B`, `value_1`: `B`, `...`]
  Provide a set of values which correspond to previously asked node data hashes
  from GetNodeData. Does not need to contain all; best effort is fine. If it
  contains none, then has no information for previous GetNodeData hashes.
  ```
  """

  alias ExWire.Packet
  require Logger

  @behaviour Packet

  @type t :: %__MODULE__{
          values: list(binary())
        }

  defstruct values: []

  @doc """
  Returns the relative message id offset for this message.

  This will help determine what its message ID is relative to other Packets in the same Capability.
  """
  @impl true
  @spec message_id_offset() :: 0x0E
  def message_id_offset do
    0x0E
  end

  @doc """
  Given a NodeData packet, serializes for transport over Eth Wire Protocol.

  ## Examples

      iex> %ExWire.Packet.Capability.Eth.NodeData{values: [<<1::256>>, <<2::256>>]}
      ...> |> ExWire.Packet.Capability.Eth.NodeData.serialize()
      [<<1::256>>, <<2::256>>]
  """
  @impl true
  @spec serialize(t()) :: ExRLP.t()
  def serialize(packet = %__MODULE__{}) do
    packet.values
  end

  @doc """
  Given an RLP-encoded NodeData packet from Eth Wire Protocol,
  decodes into a NodeData struct.

  ## Examples

      iex> ExWire.Packet.Capability.Eth.NodeData.deserialize([<<1::256>>, <<2::256>>])
      %ExWire.Packet.Capability.Eth.NodeData{values: [<<1::256>>, <<2::256>>]}
  """
  @impl true
  @spec deserialize(ExRLP.t()) :: t()
  def deserialize(rlp) do
    values = rlp

    %__MODULE__{
      values: values
    }
  end

  @doc """
  Handles a NodeData message. We do not respond.

  ## Examples

      iex> %ExWire.Packet.Capability.Eth.NodeData{values: [<<1::256>>, <<2::256>>]}
      ...> |> ExWire.Packet.Capability.Eth.NodeData.handle()
      :ok
  """
  @impl true
  @spec handle(t()) :: ExWire.Packet.handle_response()
  def handle(_packet = %__MODULE__{}) do
    :ok
  end
end
