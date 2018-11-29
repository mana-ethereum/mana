defmodule ExWire.Packet.Capability.Eth.GetBlockHeaders do
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

  alias Blockchain.Block
  alias ExWire.Bridge.Sync
  alias ExWire.Packet
  alias ExWire.Packet.Capability.Eth.BlockHeaders
  require Logger

  @behaviour ExWire.Packet

  @sync Application.get_env(:ex_wire, :sync_mock, Sync)
  @max_headers_supported 100

  @type t :: %__MODULE__{
          block_identifier: Packet.block_identifier(),
          max_headers: pos_integer(),
          skip: pos_integer(),
          reverse: boolean()
        }

  defstruct [
    :block_identifier,
    :max_headers,
    :skip,
    :reverse
  ]

  @doc """
  Returns the relative message id offset for this message.
  This will help determine what its message ID is relative to other Packets in the same Capability.
  """
  @impl true
  @spec message_id_offset() :: 3
  def message_id_offset do
    0x03
  end

  @doc """
  Given a GetBlockHeaders packet, serializes for transport over Eth Wire Protocol.

  ## Examples

      iex> %ExWire.Packet.Capability.Eth.GetBlockHeaders{block_identifier: 5, max_headers: 10, skip: 2, reverse: true}
      ...> |> ExWire.Packet.Capability.Eth.GetBlockHeaders.serialize
      [5, 10, 2, 1]

      iex> %ExWire.Packet.Capability.Eth.GetBlockHeaders{block_identifier: <<5>>, max_headers: 10, skip: 2, reverse: false}
      ...> |> ExWire.Packet.Capability.Eth.GetBlockHeaders.serialize
      [<<5>>, 10, 2, 0]
  """
  @impl true
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

      iex> ExWire.Packet.Capability.Eth.GetBlockHeaders.deserialize([5, <<10>>, <<2>>, <<1>>])
      %ExWire.Packet.Capability.Eth.GetBlockHeaders{block_identifier: 5, max_headers: 10, skip: 2, reverse: true}

      iex> ExWire.Packet.Capability.Eth.GetBlockHeaders.deserialize([<<5>>, <<10>>, <<2>>, <<0>>])
      %ExWire.Packet.Capability.Eth.GetBlockHeaders{block_identifier: <<5>>, max_headers: 10, skip: 2, reverse: false}
  """
  @impl true
  @spec deserialize(ExRLP.t()) :: t
  def deserialize(rlp) do
    [
      block_identifier,
      max_headers,
      skip,
      reverse
    ] = rlp

    %__MODULE__{
      block_identifier: block_identifier,
      max_headers: :binary.decode_unsigned(max_headers),
      skip: :binary.decode_unsigned(skip),
      reverse: :binary.decode_unsigned(reverse) == 1
    }
  end

  @doc """
  Handles a GetBlockHeaders message. We should send the block headers
  to the peer if we have them.

  For now, we do nothing. This upsets Geth as it thinks we're a bad
  peer, which, I suppose, we are.

  ## Examples

      iex> %ExWire.Packet.Capability.Eth.GetBlockHeaders{block_identifier: 5, max_headers: 10, skip: 2, reverse: true}
      ...> |> ExWire.Packet.Capability.Eth.GetBlockHeaders.handle()
      {:send,
         %ExWire.Packet.Capability.Eth.BlockHeaders{
           headers: []
         }}
  """
  @impl true
  @spec handle(ExWire.Packet.packet()) :: ExWire.Packet.handle_response()
  def handle(packet = %__MODULE__{max_headers: max_headers})
      when max_headers > @max_headers_supported do
    handle(%__MODULE__{packet | max_headers: @max_headers_supported})
  end

  def handle(packet = %__MODULE__{}) do
    headers =
      case @sync.get_current_trie() do
        {:ok, trie} ->
          get_block_headers(
            trie,
            packet.block_identifier,
            packet.max_headers,
            packet.skip,
            packet.reverse
          )

        {:error, error} ->
          _ =
            Logger.warn(fn ->
              "Error calling Sync.get_current_trie(): #{error}. Returning empty headers."
            end)

          []
      end

    {:send, %BlockHeaders{headers: headers}}
  end

  defp get_block_headers(trie, identifier, num_headers, skip, reverse) do
    get_block_headers(trie, identifier, num_headers, skip, reverse, [])
  end

  defp get_block_headers(_trie, _identifier, 0, _skip, _reverse, headers),
    do: Enum.reverse(headers)

  defp get_block_headers(trie, block_hash, num_headers, skip, reverse, headers)
       when is_binary(block_hash) do
    case Block.get_block(block_hash, trie) do
      {:ok, block} ->
        next_number = next_block_number(block.header.number, skip, reverse)

        get_block_headers(trie, next_number, num_headers - 1, skip, reverse, [
          block.header | headers
        ])

      _ ->
        _ =
          Logger.debug(fn -> "Could not find block with hash: #{Base.encode16(block_hash)}." end)

        headers
    end
  end

  defp get_block_headers(trie, block_number, num_headers, skip, reverse, headers) do
    case Block.get_block_by_number(block_number, trie) do
      {:ok, block} ->
        next_block_number = next_block_number(block.header.number, skip, reverse)

        get_block_headers(trie, next_block_number, num_headers - 1, skip, reverse, [
          block.header | headers
        ])

      _ ->
        _ = Logger.debug(fn -> "Could not find block with number: #{block_number}." end)
        []
    end
  end

  defp next_block_number(block_number, skip, reverse) do
    if reverse == true do
      block_number - skip
    else
      block_number + skip
    end
  end
end
