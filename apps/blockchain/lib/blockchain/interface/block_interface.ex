defmodule Blockchain.Interface.BlockInterface do
  @moduledoc """
  Defines an interface for methods to interact with the block chain.
  """

  @type t :: %__MODULE__{
          block_header: Block.Header.t(),
          db: MerklePatriciaTree.DB.db()
        }

  defstruct block_header: nil,
            db: nil

  @doc """
  Returns a new block interface.

  ## Examples

      iex> block_header = %Block.Header{}
      iex> db = MerklePatriciaTree.Test.random_ets_db(:new_block_interface)
      iex> Blockchain.Interface.BlockInterface.new(block_header, db)
      %Blockchain.Interface.BlockInterface{
        block_header: %Block.Header{},
        db: {MerklePatriciaTree.DB.ETS, :new_block_interface}
      }
  """
  def new(block_header, db) do
    %__MODULE__{
      block_header: block_header,
      db: db
    }
  end
end

defimpl EVM.Interface.BlockInterface, for: Blockchain.Interface.BlockInterface do
  # TODO: Add test case
  @doc """
  Returns the header of the currently being processed block.

  ## Examples

      iex> %Block.Header{number: 10}
      ...> |> Blockchain.Interface.BlockInterface.new(nil)
      ...> |> EVM.Interface.BlockInterface.get_block_header()
      %Block.Header{number: 10}
  """
  @spec get_block_header(EVM.Interface.BlockInterface.t()) :: Block.Header.t()
  def get_block_header(block_interface) do
    block_interface.block_header
  end

  @doc """
  Returns a given block when passed in a given hash of the block header.

  # TODO: Update spec to be more general

  ## Examples

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> block = %Blockchain.Block{header: %Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}}
      iex> block_hash = block |> Blockchain.Block.hash()
      iex> Blockchain.Block.put_block(block, db)
      iex> Blockchain.Interface.BlockInterface.new(%Block.Header{}, db)
      ...> |> EVM.Interface.BlockInterface.get_block_by_hash(block_hash)
      %Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}
  """
  @spec get_block_by_hash(EVM.Interface.BlockInterface.t(), EVM.hash()) :: Block.Header.t() | nil
  def get_block_by_hash(block_interface, block_hash) do
    case Blockchain.Block.get_block(block_hash, block_interface.db) do
      {:ok, block} -> block.header
      :not_found -> nil
    end
  end

  @doc """
  Returns a block that is steps blocks before the current block.

  ## Examples

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> block = %Blockchain.Block{
      ...>   transactions: [%Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1::160>>, value: 8, v: 27, r: 9, s: 10, data: "hi"}],
      ...>   header: %Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}
      ...> }
      iex> Blockchain.Block.put_block(block, db)
      iex> Blockchain.Interface.BlockInterface.new(block.header, db)
      ...> |> EVM.Interface.BlockInterface.get_ancestor_header(0)
      ...> |> Block.Header.hash()
      <<78, 28, 127, 10, 192, 253, 127, 239, 254, 179, 39, 34, 245, 44, 152, 98, 128, 71, 238, 155, 100, 161, 199, 71, 243, 223, 172, 191, 74, 99, 128, 63>>
  """
  @spec get_ancestor_header(EVM.Interface.BlockInterface.t(), non_neg_integer()) ::
          Block.Header.t() | nil
  def get_ancestor_header(_block_interface, n) when n < 0 or n > 256, do: nil

  def get_ancestor_header(block_interface, nth_ancestor) do
    get_ancestor_header(block_interface, block_interface.block_header, nth_ancestor)
  end

  @spec get_ancestor_header(
          EVM.Interface.BlockInterface.t(),
          Block.Header.t(),
          non_neg_integer()
        ) :: Block.Header.t()
  defp get_ancestor_header(_block_interface, block_header, 0) do
    block_header
  end

  defp get_ancestor_header(block_interface, block_header, n) do
    parent_header = get_block_by_hash(block_interface, block_header.parent_hash)
    get_ancestor_header(block_interface, parent_header, n - 1)
  end
end
