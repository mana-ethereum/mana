defmodule Blockchain.Blocktree do
  @moduledoc """
  Blocktree provides functions for adding blocks to the
  overall blocktree and forming a consistent blockchain.
  """
  defmodule InvalidBlockError do
    defexception [:message]
  end

  alias Blockchain.{Block, Chain, Genesis}
  alias MerklePatriciaTree.DB

  defstruct best_block: nil

  @type t :: %__MODULE__{best_block: Block.t() | nil}

  @doc """
  Creates a new empty blocktree.
  """
  @spec new_tree() :: t
  def new_tree() do
    %__MODULE__{}
  end

  @doc """
  Verifies a block is valid, and if so, adds it to the block tree.
  This performs four steps.

  1. Find the parent block
  2. Verfiy the block against its parent block
  3. If valid, put the block into our DB
  """
  @spec verify_and_add_block(t, Chain.t(), Block.t(), DB.db(), boolean()) ::
          {:ok, t} | :parent_not_found | {:invalid, [atom()]}
  def verify_and_add_block(
        blocktree,
        chain,
        block,
        db,
        do_validate \\ true,
        specified_block_hash \\ nil
      ) do
    parent =
      case Block.get_parent_block(block, db) do
        :genesis -> nil
        {:ok, parent} -> parent
        :not_found -> :parent_not_found
      end

    validation =
      if do_validate,
        do: Block.validate(block, chain, parent, db),
        else: :valid

    with :valid <- validation do
      {:ok, block_hash} = Block.put_block(block, db, specified_block_hash)

      # Cache computed block hash
      block = %{block | block_hash: block_hash}

      updated_blocktree = update_best_block(blocktree, block)

      {:ok, updated_blocktree}
    end
  end

  @spec update_best_block(t, Block.t()) :: t
  defp update_best_block(blocktree, block) do
    best_block = blocktree.best_block

    new_best_block =
      if is_nil(best_block) || block.header.number > best_block.header.number ||
           (block.header.number == best_block.header.number &&
              block.header.difficulty > best_block.header.difficulty),
         do: block,
         else: best_block

    %{blocktree | best_block: new_best_block}
  end

  @doc """
  Returns the best block in a tree, which is either the listed best block,
  or it's the genesis block, which we create.

  Note: we load the block by the block_hash, instead of taking it
        directly from the tree.
  """
  @spec get_best_block(t(), Chain.t(), DB.db()) :: {:ok, Block.t()} | {:error, any()}
  def get_best_block(blocktree, chain, db) do
    if block = blocktree.best_block do
      {:ok, block}
    else
      {:ok, Genesis.create_block(chain, db)}
    end
  end
end
