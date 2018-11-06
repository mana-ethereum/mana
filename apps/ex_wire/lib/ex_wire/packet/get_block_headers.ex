defmodule ExWire.Packet.GetBlockHeaders do
  @moduledoc """
  Requests block headers starting from a given hash.

  ```
  **GetBlockHeaders** [`+0x03`: `P`, `block`: { `P` , `B_32` }, `maxHeaders`: `P`, `skip`: `P`, `reverse`: `P` in { `0` , `1` } ]
  Require peer to return a BlockHeaders message. Reply
  must contain a number of block headers, of rising number when reverse is 0,
  falling when 1, skip blocks apart, beginning at block block (denoted by either
  number or hash) in the canonical chain, and with at most maxHeaders items.
  ```
  """

  alias ExWire.Packet
  alias ExWire.Packet.BlockHeaders

  @behaviour ExWire.Packet

  @type t :: %__MODULE__{
          block_identifier: Packet.block_identifier(),
          max_headers: integer(),
          skip: integer(),
          reverse: boolean()
        }

  defstruct [
    :block_identifier,
    :max_headers,
    :skip,
    :reverse
  ]

  @doc """
  Given a GetBlockHeaders packet, serializes for transport over Eth Wire Protocol.

  ## Examples

      iex> %ExWire.Packet.GetBlockHeaders{block_identifier: 5, max_headers: 10, skip: 2, reverse: true}
      ...> |> ExWire.Packet.GetBlockHeaders.serialize
      [5, 10, 2, 1]

      iex> %ExWire.Packet.GetBlockHeaders{block_identifier: <<5>>, max_headers: 10, skip: 2, reverse: false}
      ...> |> ExWire.Packet.GetBlockHeaders.serialize
      [<<5>>, 10, 2, 0]
  """
  @spec serialize(t) :: ExRLP.t()
  def serialize(packet = %__MODULE__{}) do
    [
      packet.block_identifier,
      packet.max_headers,
      packet.skip,
      if(packet.reverse, do: 1, else: 0)
    ]
  end

  @doc """
  Given an RLP-encoded GetBlockHeaders packet from Eth Wire Protocol,
  decodes into a GetBlockHeaders struct.

  ## Examples

      iex> ExWire.Packet.GetBlockHeaders.deserialize([5, 10, 2, 1])
      %ExWire.Packet.GetBlockHeaders{block_identifier: 5, max_headers: 10, skip: 2, reverse: true}

      iex> ExWire.Packet.GetBlockHeaders.deserialize([<<5>>, 10, 2, 0])
      %ExWire.Packet.GetBlockHeaders{block_identifier: <<5>>, max_headers: 10, skip: 2, reverse: false}
  """
  @spec deserialize(ExRLP.t()) :: t
  def deserialize(rlp) do
    [
      block_identifier,
      max_headers,
      skip,
      reverse
    ] = rlp

    %__MODULE__{
      block_identifier: :binary.decode_unsigned(block_identifier),
      max_headers: :binary.decode_unsigned(max_headers),
      skip: :binary.decode_unsigned(skip),
      reverse: :binary.decode_unsigned(reverse) == 1
    }
  end

  @doc """
  Handles a GetBlockHeaders message. We shoud send the block headers
  to the peer if we have them. For now, we'll do nothing.

  ## Examples

      iex> %ExWire.Packet.GetBlockHeaders{block_identifier: 5, max_headers: 10, skip: 2, reverse: true}
      ...> |> ExWire.Packet.GetBlockHeaders.handle()
      :ok
  """
  @spec handle(ExWire.Packet.packet()) :: ExWire.Packet.handle_response()
  def handle(_packet = %__MODULE__{}) do
    {:send,
     %BlockHeaders{
       headers: []
     }}
  end
end
