defmodule ExWire.Packet.BlockHeaders do
  @moduledoc """
  Eth Wire Packet for getting block headers from a peer.

  ```
  **BlockHeaders** [`+0x04`, `blockHeader_0`, `blockHeader_1`, ...]

  Reply to `GetBlockHeaders`. The items in the list (following the message ID) are
  block headers in the format described in the main Ethereum specification, previously
  asked for in a `GetBlockHeaders` message. This may validly contain no block headers
  if no block headers were able to be returned for the `GetBlockHeaders` query.
  ```
  """

  require Logger

  @behaviour ExWire.Packet

  @type t :: %__MODULE__{
    headers: [Block.Header.t]
  }

  defstruct [
    :headers
  ]

  @doc """
  Given a BlockHeaders packet, serializes for transport over Eth Wire Protocol.

  ## Examples

      iex> %ExWire.Packet.BlockHeaders{
      ...>   headers: [
      ...>     %Block.Header{parent_hash: <<1::256>>, ommers_hash: <<2::256>>, beneficiary: <<3::160>>, state_root: <<4::256>>, transactions_root: <<5::256>>, receipts_root: <<6::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<7::256>>, nonce: <<8::64>>}
      ...>   ]
      ...> }
      ...> |> ExWire.Packet.BlockHeaders.serialize
      [ [<<1::256>>, <<2::256>>, <<3::160>>, <<4::256>>, <<5::256>>, <<6::256>>, <<>>, 5, 1, 5, 3, 6, "Hi mom", <<7::256>>, <<8::64>>] ]
  """
  @spec serialize(t) :: ExRLP.t
  def serialize(packet=%__MODULE__{}) do
    for header <- packet.headers, do: Block.Header.serialize(header)
  end

  @doc """
  Given an RLP-encoded BlockBodies packet from Eth Wire Protocol,
  decodes into a BlockBodies struct.

  ## Examples

      iex> ExWire.Packet.BlockHeaders.deserialize([ [<<1::256>>, <<2::256>>, <<3::160>>, <<4::256>>, <<5::256>>, <<6::256>>, <<>>, <<5>>, <<1>>, <<5>>, <<3>>, <<6>>, "Hi mom", <<7::256>>, <<8::64>>] ])
      %ExWire.Packet.BlockHeaders{
        headers: [
          %Block.Header{parent_hash: <<1::256>>, ommers_hash: <<2::256>>, beneficiary: <<3::160>>, state_root: <<4::256>>, transactions_root: <<5::256>>, receipts_root: <<6::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<7::256>>, nonce: <<8::64>>},
        ]
      }
  """
  @spec deserialize(ExRLP.t) :: t
  def deserialize(rlp) do
    headers = for header <- rlp, do: Block.Header.deserialize(header)

    %__MODULE__{
      headers: headers
    }
  end

  @doc """
  Handles a BlockHeaders message. This is when we have received
  a given set of block headers back from a peer.

  ## Examples

      iex> %ExWire.Packet.BlockHeaders{headers: [ %Block.Header{parent_hash: <<1::256>>, ommers_hash: <<2::256>>, beneficiary: <<3::160>>, state_root: <<4::256>>, transactions_root: <<5::256>>, receipts_root: <<6::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<7::256>>, nonce: <<8::64>>} ]}
      ...> |> ExWire.Packet.BlockHeaders.handle()
      :ok
  """
  @spec handle(ExWire.Packet.packet) :: ExWire.Packet.handle_response
  def handle(packet=%__MODULE__{}) do
    # TODO: Do.
    Logger.debug("[Packet] Peer sent #{Enum.count(packet.headers)} header(s)")

    # packet.headers |> Exth.inspect("Got headers, requesting more?")

    :ok
  end

end
