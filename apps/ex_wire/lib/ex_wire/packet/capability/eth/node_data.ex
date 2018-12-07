defmodule ExWire.Packet.Capability.Eth.NodeData do
  @moduledoc """
  Eth Wire Packet for getting NodeData from a peer.

  ```
  **NodeData** [+0x0e, value_0: B, value_1: B, ...]
  Provide a set of values which correspond to previously asked node data hashes from GetNodeData.
  Does not need to contain all; best effort is fine.
  If it contains none, then has no information for previous GetNodeData hashes.
  ```
  """

  require Logger

  @behaviour ExWire.Packet

  @type t :: %__MODULE__{
          hashes_to_nodes: %{}
        }

  defstruct [
    :hashes_to_nodes
  ]

  @spec new(%{}) :: t()
  def new(hashes_to_nodes) do
    %__MODULE__{
      hashes_to_nodes: hashes_to_nodes
    }
  end

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
  """
  @impl true
  @spec serialize(t) :: ExRLP.t()
  def serialize(packet = %__MODULE__{}) do
    for {hash, node_data} <- packet.hashes_to_nodes, do: [hash, node_data]
  end

  @doc """
  Given an RLP-encoded NodeData packet from Eth Wire Protocol, decodes into
  a `NodeData` struct.
  """
  @impl true
  @spec deserialize(ExRLP.t()) :: t
  def deserialize(rlp) do
    hashes_to_nodes =
      for [hash, node_data] <- rlp,
          do:
            {hash, node_data}
            |> Map.new(%{})

    new(hashes_to_nodes)
  end

  @doc """
  Handles a NodeData message.

  ## Examples

      iex> %ExWire.Packet.Capability.Eth.NodeData.new([])
      ...> |> ExWire.Packet.Capability.Eth.NodeData.handle()
      :ok
  """
  @impl true
  @spec handle(ExWire.Packet.packet()) :: ExWire.Packet.handle_response()
  def handle(packet = %__MODULE__{}) do
    :ok = Logger.info("[Packet] Peer sent #{Enum.count(packet.hashes_to_nodes)} Node(s).")

    :ok
  end
end
