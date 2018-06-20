defmodule Blockchain.Interface.BlockInterface do
  @moduledoc """
  Defines an interface for methods to interact with the block chain.
  """

  @type t :: %__MODULE__{
          block_header: Header.t(),
          db: MerklePatriciaTree.DB.db()
        }

  defstruct block_header: nil,
            db: nil

  @doc """
  Returns a new block interface.

  ## Examples

      iex> block_header = %EthCore.Block.Header{}
      iex> db = MerklePatriciaTree.Test.random_ets_db(:new_block_interface)
      iex> Blockchain.Interface.BlockInterface.new(block_header, db)
      %Blockchain.Interface.BlockInterface{
        block_header: %EthCore.Block.Header{},
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
  alias EthCore.Block.Header
  alias Blockchain.Block

  # TODO: Add test case
  @doc """
  Returns the header of the currently being processed block.

  ## Examples

      iex> %EthCore.Block.Header{number: 10}
      ...> |> Blockchain.Interface.BlockInterface.new(nil)
      ...> |> EVM.Interface.BlockInterface.get_block_header()
      %EthCore.Block.Header{number: 10}
  """
  @spec get_block_header(EVM.Interface.BlockInterface.t()) :: Header.t()
  def get_block_header(block_interface) do
    block_interface.block_header
  end

  @doc """
  Returns a given block when passed in a given hash of the block header.

  # TODO: Update spec to be more general

  ## Examples

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> block = %Blockchain.Block{header: %EthCore.Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}}
      iex> block_hash = block |> Blockchain.Block.hash()
      iex> Blockchain.Block.put_block(block, db)
      iex> Blockchain.Interface.BlockInterface.new(%EthCore.Block.Header{}, db)
      ...> |> EVM.Interface.BlockInterface.get_block_by_hash(block_hash)
      %EthCore.Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}
  """
  @spec get_block_by_hash(EVM.Interface.BlockInterface.t(), EVM.hash()) :: Header.t() | nil
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
      ...>   header: %EthCore.Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}
      ...> }
      iex> Blockchain.Block.put_block(block, db)
      iex> Blockchain.Interface.BlockInterface.new(block.header, db)
      ...> |> EVM.Interface.BlockInterface.get_block_by_number(0)
      <<78, 28, 127, 10, 192, 253, 127, 239, 254, 179, 39, 34, 245, 44, 152, 98, 128, 71, 238, 155, 100, 161, 199, 71, 243, 223, 172, 191, 74, 99, 128, 63>>
  """
  @spec get_block_by_number(EVM.Interface.BlockInterface.t(), non_neg_integer()) ::
          Header.t() | nil
  def get_block_by_number(block_interface, steps) do
    header_hash = Header.hash(block_interface.block_header)

    result =
      Block.get_block_hash_by_steps(
        header_hash,
        steps,
        block_interface.db
      )

    case result do
      {:ok, block_header} -> block_header
      :not_found -> nil
    end
  end
end
