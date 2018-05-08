defmodule ExWire.Packet.GetBlockBodies do
  @moduledoc """
  Request the bodies for a set of blocks by hash.

  ```
  `GetBlockBodies` [`+0x05`, `hash_0`: `B_32`, `hash_1`: `B_32`, ...]

  Require peer to return a BlockBodies message. Specify the set of blocks that
  we're interested in with the hashes.
  ```
  """

  @behaviour ExWire.Packet

  @type t :: %__MODULE__{
          hashes: [binary()]
        }

  defstruct hashes: []

  @doc """
  Given a GetBlockBodies packet, serializes for transport over Eth Wire Protocol.

  ## Examples

      iex> %ExWire.Packet.GetBlockBodies{hashes: [<<5>>, <<6>>]}
      ...> |> ExWire.Packet.GetBlockBodies.serialize
      [<<5>>, <<6>>]
  """
  @spec serialize(t) :: ExRLP.t()
  def serialize(packet = %__MODULE__{}) do
    packet.hashes
  end

  @doc """
  Given an RLP-encoded GetBlockBodies packet from Eth Wire Protocol,
  decodes into a GetBlockBodies struct.

  ## Examples

      iex> ExWire.Packet.GetBlockBodies.deserialize([<<5>>, <<6>>])
      %ExWire.Packet.GetBlockBodies{hashes: [<<5>>, <<6>>]}
  """
  @spec deserialize(ExRLP.t()) :: t
  def deserialize(rlp) do
    # verify it's a list
    hashes = [_h | _t] = rlp

    %__MODULE__{
      hashes: hashes
    }
  end

  @doc """
  Handles a GetBlockBodies message. We shoud send the block bodies
  to the peer if we have them. For now, we'll do nothing.

  ## Examples

      iex> %ExWire.Packet.GetBlockBodies{hashes: [<<5>>, <<6>>]}
      ...> |> ExWire.Packet.GetBlockBodies.handle()
      :ok
  """
  @spec handle(ExWire.Packet.packet()) :: ExWire.Packet.handle_response()
  def handle(_packet = %__MODULE__{}) do
    :ok
  end
end
