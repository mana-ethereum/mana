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
