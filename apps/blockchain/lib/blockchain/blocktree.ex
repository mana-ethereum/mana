defmodule Blockchain.Blocktree do
  @moduledoc """
  Blocktree provides functions for adding blocks to the
  overall blocktree and forming a consistent blockchain.

  We have two important issues to handle after we get a new
  unknown block:

  1. Do we accept the block? Is it valid and does it connect to
     a known parent?

  2. After we've accepted it, is it (by total difficulty) the canonical block?
     Does it become the canonical block after other blocks have been added
     to the block chain?

  TODO: Number 1.
  """
  defmodule InvalidBlockError do
    defexception [:message]
  end

  alias Blockchain.{Block, Chain}

  defstruct block: nil,
            children: [],
            total_difficulty: 0,
            parent_map: %{}

  @type t :: %__MODULE__{
          block: :root | Block.t(),
          children: %{EVM.hash() => t},
          total_difficulty: integer(),
          parent_map: %{EVM.hash() => EVM.hash()}
        }

  @doc """
  Creates a new empty blocktree.

  ## Examples
  """
  @spec new() :: t
  def new() do
    %__MODULE__{
      block: :root,
      children: %{},
      total_difficulty: 0,
      parent_map: %{}
    }
  end

  # Creates a new trie with a given root.
  # This should be used to create sub-trees internally.
  @spec rooted(Block.t()) :: t
  defp rooted(gen_block) do
    %__MODULE__{
      block: gen_block,
      children: %{},
      total_difficulty: gen_block.header.difficulty,
      parent_map: %{}
    }
  end

  @doc """
  Traverses a tree to find the most canonical block.
  This decides based on blocks with the highest difficulty recursively walking down the tree.
  Canonical blockchain is defined in Section 10 of the Yellow Paper.
  """
  @spec get_canonical_block(t) :: Block.t()
  def get_canonical_block(blocktree) do
    case Enum.count(blocktree.children) do
      0 ->
        blocktree.block

      _ ->
        {_hash, tree} = Enum.max_by(blocktree.children, fn {_k, v} -> v.total_difficulty end)

        get_canonical_block(tree)
    end
  end

  @doc """
  Verifies a block is valid, and if so, adds it to the block tree.
  This performs four steps.

  1. Find the parent block
  2. Verfiy the block against its parent block
  3. If valid, put the block into our DB
  4. Add the block to our blocktree.
  """
  @spec verify_and_add_block(t, Chain.t(), Block.t(), MerklePatriciaTree.DB.db(), boolean()) ::
          {:ok, t} | :parent_not_found | {:invalid, [atom()]}
  def verify_and_add_block(blocktree, chain, block, db, do_validate \\ true) do
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
      {:ok, block_hash} = Block.put_block(block, db)
      # Cache computed block hash
      block = %{block | block_hash: block_hash}

      {:ok, add_block(blocktree, block)}
    end
  end

  @doc """
  Adds a block to our complete block tree. We should perform this action
  only after we've verified the block is valid.

  Note, if the block does not fit into the current tree (e.g. if the parent block
  isn't known to us yet), then we will raise an exception.

  TODO: Perhaps we should store the block until we encounter the parent block?
  """
  @spec add_block(t, Block.t()) :: t
  def add_block(blocktree, block) do
    block_hash = block.block_hash || Block.hash(block)
    parent_map = Map.put(blocktree.parent_map, block_hash, block.header.parent_hash)
    blocktree = %{blocktree | parent_map: parent_map}

    case get_path_to_root(blocktree, block_hash) do
      # TODO: How we can better handle this case?
      :no_path ->
        raise InvalidBlockError, "No path to root"

      {:ok, path} ->
        do_add_block(blocktree, block, block_hash, path)
    end
  end

  # Recursively walk tree and to add children block
  @spec do_add_block(t, Block.t(), EVM.hash(), [EVM.hash()]) :: t
  defp do_add_block(blocktree, block, block_hash, path) do
    case path do
      [] ->
        tree = rooted(block)
        new_children = Map.put(blocktree.children, block_hash, tree)

        total_difficulty = max_difficulty(new_children)
        %{blocktree | children: new_children, total_difficulty: total_difficulty}

      [path_hash | rest] ->
        case blocktree.children[path_hash] do
          # this should be impossible unless the tree is missing nodes
          nil ->
            raise InvalidBlockError, "Invalid path to root, missing path #{inspect(path_hash)}"

          sub_tree ->
            # Recurse and update the children of this tree. Note, we may also need to adjust the total
            # difficulty of this subtree.
            new_child = do_add_block(sub_tree, block, block_hash, rest)

            # TODO: Does this parent_hash only exist at the root node?
            %{
              blocktree
              | children: Map.put(blocktree.children, path_hash, new_child),
                total_difficulty: max(blocktree.total_difficulty, new_child.total_difficulty)
            }
        end
    end
  end

  # Gets the maximum difficulty amoungst a set of child nodes
  @spec max_difficulty(%{EVM.hash() => t}) :: integer()
  defp max_difficulty(children) do
    Enum.map(children, fn {_, child} -> child.total_difficulty end) |> Enum.max()
  end

  @doc """
  Returns a path from the given block's parent all the way up to the root of the tree. This will
  raise if any node does not have a valid path to root, and runs in O(n) time with regards to the
  height of the tree.

  Because the blocktree doesn't have structure based on retrieval, we store a sheet of nodes to
  parents for each subtree. That way, we can always find the correct path the traverse the tree.

  This obviously requires us to store a significant extra amount of data about the tree.

  ## Examples
  """
  @spec get_path_to_root(t, EVM.hash()) :: {:ok, [EVM.hash()]} | :no_path
  def get_path_to_root(blocktree, hash) do
    case do_get_path_to_root(blocktree, hash) do
      {:ok, path} -> {:ok, Enum.reverse(path)}
      els -> els
    end
  end

  @spec do_get_path_to_root(t, EVM.hash()) :: {:ok, [EVM.hash()]} | :no_path
  defp do_get_path_to_root(blocktree, hash) do
    case Map.get(blocktree.parent_map, hash, :no_path) do
      :no_path ->
        :no_path

      <<0::256>> ->
        {:ok, []}

      parent_hash ->
        case do_get_path_to_root(blocktree, parent_hash) do
          :no_path -> :no_path
          {:ok, path} -> {:ok, [parent_hash | path]}
        end
    end
  end

  @doc """
  Simple function to inspect the structure of a block tree.
  Simply walks through the tree and prints the block number
  and hash as a set of sub-lists.

  Note: I don't believe this fits the rules for tail call
  recursion, so we need to be careful to not use this for
  excessively large trees.
  """
  @spec inspect_tree(t) :: [any()]
  def inspect_tree(blocktree) do
    value =
      case blocktree.block do
        :root -> :root
        block -> {block.header.number, block.block_hash}
      end

    children = for {_, child} <- blocktree.children, do: inspect_tree(child)

    [value | children]
  end
end
