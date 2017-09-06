defmodule Blockchain.Interface.BlockInterface do
  @moduledoc """
  Defines an interface for methods to interact with the block chain.
  """

  @type t :: %__MODULE__{
    block_header: Block.Header.t,
    db: MerklePatriciaTree.DB.db
  }

  defstruct [
    block_header: nil,
    db: nil
  ]

  @doc """
  Returns a new block interface.

  ## Examples

      iex> block_header = %Block.Header{}
      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> Blockchain.Interface.BlockInterface.new(block_header, db)
      %Blockchain.Interface.BlockInterface{}
  """
  def new(block_header, db) do
    %__MODULE__{
      block_header: block_header,
      db: db,
    }
  end
end

defimpl EVM.Interface.BlockInterface, for: Blockchain.Interface.BlockInterface do

  # TODO: Add test case
  @spec get_block_header(EVM.Interface.BlockInterface.t) :: Block.Header.t
  def get_block_header(block_interface) do
    block_interface.block_header
  end

  # TODO: Add test case
  # TODO: Update spec generally
  @spec get_block_by_hash(EVM.Interface.BlockInterface.t, EVM.hash) :: Block.Header.t | nil
  def get_block_by_hash(block_interface, block_hash) do
    case Blockchain.Block.get_block(block_hash, block_interface.db) do
      {:ok, block} -> block.header
      :not_found -> nil
    end
  end

end