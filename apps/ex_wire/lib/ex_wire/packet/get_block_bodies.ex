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

  alias Blockchain.Block
  alias ExWire.Bridge.Sync
  alias ExWire.Packet.BlockBodies
  require Logger

  @sync Application.get_env(:ex_wire, :sync_mock, Sync)

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
  Handles a GetBlockBodies message. We should send the block bodies
  to the peer if we have them. For now, we'll do nothing.

  ## Examples
      # Bodies not found test
      iex> %ExWire.Packet.GetBlockBodies{hashes: [<<5>>, <<6>>]}
      ...> |> ExWire.Packet.GetBlockBodies.handle()
      {:send, %ExWire.Packet.BlockBodies{blocks: []}}

      # Body found test
      iex> ExWire.BridgeSyncMock.start_link(%{})
      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> trie = db |> MerklePatriciaTree.Trie.new()
      iex> block = %Blockchain.Block{
      ...>   transactions: [%Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1::160>>, value: 8, v: 27, r: 9, s: 10, data: "hi"}],
      ...>   header: %Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}
      ...> }
      iex> Blockchain.Block.put_block(block, trie)
      iex> ExWire.BridgeSyncMock.set_current_trie(trie)
      iex> ExWire.Struct.Block.new(block)
      iex> %ExWire.Packet.GetBlockBodies{hashes: [block |> Blockchain.Block.hash]}
      ...> |> ExWire.Packet.GetBlockBodies.handle()
      {:send,%ExWire.Packet.BlockBodies{blocks: [%ExWire.Struct.Block{ommers: [],ommers_rlp: [],transactions: [%Blockchain.Transaction{data: "hi",gas_limit: 7,gas_price: 6,init: "",nonce: 5,r: 9,s: 10,to: <<0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1>>,v: 27,value: 8}], transactions_rlp: [[<<5>>, <<6>>, <<7>>, <<1::160>>, <<8>>, "hi", <<27>>, <<9>>, <<10>>]]}]}}
  """
  @spec handle(ExWire.Packet.packet()) :: ExWire.Packet.handle_response()
  def handle(packet = %__MODULE__{}) do
    bodies =
      case @sync.get_current_trie() do
        {:ok, trie} ->
          get_block_bodies(trie, packet.hashes)

        {:error, error} ->
          _ =
            Logger.debug(fn ->
              "Error calling Sync.get_current_trie(): #{error}. Returning empty headers."
            end)

          []
      end

    {:send, BlockBodies.new(bodies)}
  end

  defp get_block_bodies(trie, hashes) do
    hashes
    |> Stream.map(fn hash ->
      case Block.get_block(hash, trie) do
        {:ok, block} ->
          ExWire.Struct.Block.new(block)

        :not_found ->
          nil
      end
    end)
    |> Stream.reject(fn elem -> elem == nil end)
    |> Enum.to_list()
  end
end
