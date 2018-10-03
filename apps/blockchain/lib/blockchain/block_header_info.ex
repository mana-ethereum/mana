defmodule Blockchain.BlockHeaderInfo do
  @moduledoc """
  Module to interact with the block header in the blockchain.
  """

  @behaviour EVM.BlockHeaderInfo

  @type t :: %__MODULE__{
          block_header: Block.Header.t(),
          db: MerklePatriciaTree.DB.db()
        }

  defstruct [:block_header, :db]

  @doc """
  Returns a new block interface.

  ## Examples

      iex> block_header = %Block.Header{}
      iex> db = MerklePatriciaTree.Test.random_ets_db(:new_block_header_info)
      iex> Blockchain.BlockHeaderInfo.new(block_header, db)
      %Blockchain.BlockHeaderInfo{
        block_header: %Block.Header{},
        db: {MerklePatriciaTree.DB.ETS, :new_block_header_info}
      }
  """
  def new(block_header, db) do
    %__MODULE__{
      block_header: block_header,
      db: db
    }
  end

  @doc """
  Returns the header of the currently being processed block.

  ## Examples

      iex> %Block.Header{number: 10}
      ...> |> Blockchain.BlockHeaderInfo.new(nil)
      ...> |> Blockchain.BlockHeaderInfo.get_block_header()
      %Block.Header{number: 10}
  """
  @impl true
  def get_block_header(block_header_info) do
    block_header_info.block_header
  end

  @doc """
  Returns a block that is `n` blocks before the current block.

  ## Examples

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> parent_block = %Blockchain.Block{
      ...>   transactions: [%Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1::160>>, value: 8, v: 27, r: 9, s: 10, data: "hi"}],
      ...>   header: %Block.Header{number: 4, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}
      ...> }
      iex> block = %Blockchain.Block{
      ...>   transactions: [],
      ...>   header: %Block.Header{number: 5, parent_hash: Blockchain.Block.hash(parent_block), beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>> }
      ...> }
      iex> Blockchain.Block.put_block(parent_block, db)
      iex> Blockchain.Block.put_block(block, db)
      iex> Blockchain.BlockHeaderInfo.new(block.header, db)
      ...> |> Blockchain.BlockHeaderInfo.get_ancestor_header(1)
      ...> |> Block.Header.hash()
      <<225, 215, 217, 9, 148, 107, 83, 180, 84, 178, 164, 158, 204, 244, 31, 54, 216, 217, 104, 231, 118, 243, 114, 255, 227, 229, 130, 79, 152, 251, 199, 47>>
  """
  @impl true
  def get_ancestor_header(_block_header_info, n) when n <= 0 or n > 256, do: nil

  def get_ancestor_header(block_header_info, nth_ancestor) do
    do_get_ancestor_header(block_header_info, block_header_info.block_header, nth_ancestor)
  end

  defp do_get_ancestor_header(_block_header_info, block_header, 0) do
    block_header
  end

  defp do_get_ancestor_header(block_header_info, block_header, n) do
    parent_header = get_block_by_hash(block_header_info, block_header.parent_hash)
    do_get_ancestor_header(block_header_info, parent_header, n - 1)
  end

  defp get_block_by_hash(block_header_info, block_hash) do
    case Blockchain.Block.get_block(block_hash, block_header_info.db) do
      {:ok, block} -> block.header
      :not_found -> nil
    end
  end
end
