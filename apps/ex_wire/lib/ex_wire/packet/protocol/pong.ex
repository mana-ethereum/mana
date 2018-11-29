defmodule ExWire.Packet.Protocol.Pong do
  @moduledoc """
  Pong is the response to a Ping message.

  ```
  **Pong** `0x03` []

  Reply to peer's `Ping` packet.
  ```
  """

  @behaviour ExWire.Packet

  @type t :: %__MODULE__{}

  defstruct []

  @spec message_id_offset() :: integer()
  def message_id_offset() do
    0x03
  end

  @doc """
  Given a Pong packet, serializes for transport over Eth Wire Protocol.

  ## Examples

      iex> %ExWire.Packet.Protocol.Pong{}
      ...> |> ExWire.Packet.Protocol.Pong.serialize
      []
  """
  @spec serialize(t) :: ExRLP.t()
  def serialize(_packet = %__MODULE__{}) do
    []
  end

  @doc """
  Given an RLP-encoded Pong packet from Eth Wire Protocol,
  decodes into a Pong struct.

  ## Examples

      iex> ExWire.Packet.Protocol.Pong.deserialize([])
      %ExWire.Packet.Protocol.Pong{}
  """
  @spec deserialize(ExRLP.t()) :: t
  def deserialize(rlp) do
    [] = rlp

    %__MODULE__{}
  end

  @doc """
  Handles a Pong message. We should track the round-trip time since the
  corresponding Ping was sent to know how fast this peer is.

  ## Examples

      iex> ExWire.Packet.Protocol.Pong.handle(%ExWire.Packet.Protocol.Pong{})
      :ok
  """
  @spec handle(ExWire.Packet.packet()) :: ExWire.Packet.handle_response()
  def handle(_packet = %__MODULE__{}) do
    # TODO: Track RTT time

    :ok
  end
end
