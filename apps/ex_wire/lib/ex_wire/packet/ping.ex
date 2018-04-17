defmodule ExWire.Packet.Ping do
  @moduledoc """
  Ping is used to determine round-trip time of messages to a peer.

  ```
  **Ping** `0x02` []

  Requests an immediate reply of Pong from the peer.
  ```
  """

  require Logger

  @behaviour ExWire.Packet

  @type t :: %__MODULE__{}

  defstruct []

  @doc """
  Given a Ping packet, serializes for transport over Eth Wire Protocol.

  ## Examples

      iex> %ExWire.Packet.Ping{}
      ...> |> ExWire.Packet.Ping.serialize
      []
  """
  @spec serialize(t) :: ExRLP.t
  def serialize(_packet=%__MODULE__{}) do
    []
  end

  @doc """
  Given an RLP-encoded Ping packet from Eth Wire Protocol,
  decodes into a Ping struct.

  ## Examples

      iex> ExWire.Packet.Ping.deserialize([])
      %ExWire.Packet.Ping{}
  """
  @spec deserialize(ExRLP.t) :: t
  def deserialize(rlp) do
    [] = rlp

    %__MODULE__{}
  end

  @doc """
  Handles a Ping message. We send a Pong back to the peer.

  ## Examples

      iex> ExWire.Packet.Ping.handle(%ExWire.Packet.Ping{})
      {:send, %ExWire.Packet.Pong{}}
  """
  @spec handle(ExWire.Packet.packet) :: ExWire.Packet.handle_response
  def handle(_packet=%__MODULE__{}) do
    Logger.debug("[Packet] Received ping, responding pong.")

    {:send, %ExWire.Packet.Pong{}}
  end
end