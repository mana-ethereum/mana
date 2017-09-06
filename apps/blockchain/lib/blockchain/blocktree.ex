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

  alias Blockchain.Block

  defstruct [
    block: nil,
    children: [],
    total_difficulty: 0,
    parent_map: %{},
  ]

  @type t :: %__MODULE__{
    block: :root | Block.t,
    children: %{EVM.hash => t},
    total_difficulty: integer(),
    parent_map: %{EVM.hash => EVM.hash},
  }

  @doc """
  Creates a new empty blocktree.

  ## Examples

      iex> Blockchain.Blocktree.new_tree()
      %Blockchain.Blocktree{
        block: :root,
        children: %{},
        total_difficulty: 0,
        parent_map: %{}
      }
  """
  @spec new_tree() :: t
  def new_tree() do
    %__MODULE__{
      block: :root,
      children: %{},
      total_difficulty: 0,
      parent_map: %{}
    }
  end

  # Creates a new trie with a given root. This should be used to
  # create sub-trees internally.
  @spec rooted_tree(Block.t) :: t
  defp rooted_tree(gen_block) do
    %__MODULE__{
      block: gen_block,
      children: %{},
      total_difficulty: gen_block.header.difficulty,
      parent_map: %{}
    }
  end

  @doc """
  Traverses a tree to find the most canonical block. This decides based on
  blocks with the highest difficulty recursively walking down the tree.

  ## Examples

      iex> Blockchain.Blocktree.new_tree() |> Blockchain.Blocktree.get_canonical_block()
      :root

      iex> block_1 = %Blockchain.Block{block_hash: <<1>>, header: %Block.Header{number: 0, parent_hash: <<0::256>>, difficulty: 100}}
      iex> Blockchain.Blocktree.new_tree()
      ...> |> Blockchain.Blocktree.add_block(block_1)
      ...> |> Blockchain.Blocktree.get_canonical_block()
      %Blockchain.Block{block_hash: <<1>>, header: %Block.Header{difficulty: 100, number: 0, parent_hash: <<0::256>>}}

      iex> block_10 = %Blockchain.Block{block_hash: <<10>>, header: %Block.Header{number: 5, parent_hash: <<0::256>>, difficulty: 100}}
      iex> block_20 = %Blockchain.Block{block_hash: <<20>>, header: %Block.Header{number: 6, parent_hash: <<10>>, difficulty: 110}}
      iex> block_21 = %Blockchain.Block{block_hash: <<21>>, header: %Block.Header{number: 6, parent_hash: <<10>>, difficulty: 109}}
      iex> block_30 = %Blockchain.Block{block_hash: <<30>>, header: %Block.Header{number: 7, parent_hash: <<20>>, difficulty: 120}}
      iex> block_31 = %Blockchain.Block{block_hash: <<31>>, header: %Block.Header{number: 7, parent_hash: <<20>>, difficulty: 119}}
      iex> block_41 = %Blockchain.Block{block_hash: <<41>>, header: %Block.Header{number: 8, parent_hash: <<30>>, difficulty: 129}}
      iex> Blockchain.Blocktree.new_tree()
      ...> |> Blockchain.Blocktree.add_block(block_10)
      ...> |> Blockchain.Blocktree.add_block(block_20)
      ...> |> Blockchain.Blocktree.add_block(block_30)
      ...> |> Blockchain.Blocktree.add_block(block_31)
      ...> |> Blockchain.Blocktree.add_block(block_41)
      ...> |> Blockchain.Blocktree.add_block(block_21)
      ...> |> Blockchain.Blocktree.get_canonical_block()
      %Blockchain.Block{block_hash: <<41>>, header: %Block.Header{difficulty: 129, number: 8, parent_hash: <<30>>}}
  """
  @spec get_canonical_block(t) :: Block.t
  def get_canonical_block(blocktree) do
    case Enum.count(blocktree.children) do
      0 -> blocktree.block
      _ ->
        {_hash, tree} = Enum.max_by(blocktree.children, fn {_k, v} -> v.total_difficulty end)

        get_canonical_block(tree)
    end
  end

  @doc """
  Verifies a block is valid, and if so, adds it to the block tree. This performs
  four steps.

  1. Find the parent block
  2. Verfiy the block against its parent block
  3. If valid, put the block into our DB
  4. Add the block to our blocktree.

  ## Examples

      # For a genesis block
      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> gen_block = %Blockchain.Block{header: %Block.Header{number: 0, parent_hash: <<0::256>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}}
      iex> tree = Blockchain.Blocktree.new_tree()
      iex> {:ok, tree_1} = Blockchain.Blocktree.verify_and_add_block(tree, gen_block, db)
      iex> Blockchain.Blocktree.inspect_tree(tree_1)
      [:root, [{0, <<89, 182, 13, 239, 192, 71, 245, 159, 65, 228, 40, 174, 81, 122,
                      116, 133, 45, 4, 91, 192, 172, 225, 93, 228, 63, 16, 242, 184,
                      148, 210, 193, 175>>}]]

      # With a valid block
      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> block_1 = %Blockchain.Block{header: %Block.Header{number: 0, parent_hash: <<0::256>>, beneficiary: <<2, 3, 4>>, difficulty: 131_072, timestamp: 55, gas_limit: 200_000, mix_hash: <<1>>, nonce: <<2>>}}
      iex> block_2 = %Blockchain.Block{header: %Block.Header{number: 1, parent_hash: block_1 |> Blockchain.Block.hash, beneficiary: <<2, 3, 4>>, difficulty: 131_136, timestamp: 65, gas_limit: 200_000, mix_hash: <<1>>, nonce: <<2>>}}
      iex> tree = Blockchain.Blocktree.new_tree()
      iex> {:ok, tree_1} = Blockchain.Blocktree.verify_and_add_block(tree, block_1, db)
      iex> {:ok, tree_2} = Blockchain.Blocktree.verify_and_add_block(tree_1, block_2, db)
      iex> Blockchain.Blocktree.inspect_tree(tree_2)
      [:root,
            [{0,
              <<225, 253, 252, 61, 241, 46, 59, 42, 251, 150, 211, 254, 199, 72,
                253, 8, 39, 18, 180, 38, 7, 112, 155, 231, 236, 117, 239, 201,
                146, 55, 178, 122>>},
             [{1,
               <<229, 143, 106, 171, 44, 213, 138, 133, 236, 79, 132, 208, 244,
                 55, 61, 24, 61, 83, 30, 143, 71, 220, 36, 238, 80, 121, 15,
                 156, 100, 132, 83, 208>>}]]]

      # With a invalid block
      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> block_1 = %Blockchain.Block{header: %Block.Header{number: 0, parent_hash: <<0::256>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}}
      iex> block_2 = %Blockchain.Block{header: %Block.Header{number: 1, parent_hash: block_1 |> Blockchain.Block.hash, beneficiary: <<2, 3, 4>>, difficulty: 110, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}}
      iex> tree = Blockchain.Blocktree.new_tree()
      iex> {:ok, tree_1} = Blockchain.Blocktree.verify_and_add_block(tree, block_1, db)
      iex> Blockchain.Blocktree.verify_and_add_block(tree_1, block_2, db)
      {:invalid, [:invalid_gas_limit, :child_timestamp_invalid]}
  """
  @spec verify_and_add_block(t, Block.t, MerklePatriciaTree.DB.db) :: {:ok, t} | {:invalid, [atom()]}
  def verify_and_add_block(blocktree, block, db) do
    parent = case Blockchain.Block.get_parent_block(block, db) do
      :genesis -> nil
      {:ok, parent} -> parent
      els -> raise InvalidBlockError, "Failed to find parent block: #{inspect els}"
    end

    with :valid <- Block.is_fully_valid?(block, parent, db) do
      {:ok, block_hash} = Block.put_block(block, db)
      block = %{block | block_hash: block_hash} # Cache computed block hash

      {:ok, add_block(blocktree, block)}
    end
  end

  @doc """
  Adds a block to our complete block tree. We should perform this action
  only after we've verified the block is valid.

  Note, if the block does not fit into the current tree (e.g. if the parent block
  isn't known to us yet), then we will raise an exception.

  TODO: Perhaps we should store the block until we encounter the parent block?

  ## Examples

      iex> block_1 = %Blockchain.Block{block_hash: <<1>>, header: %Block.Header{number: 5, parent_hash: <<0::256>>, difficulty: 100}}
      iex> block_2 = %Blockchain.Block{block_hash: <<2>>, header: %Block.Header{number: 6, parent_hash: <<1>>, difficulty: 110}}
      iex> Blockchain.Blocktree.new_tree()
      ...> |> Blockchain.Blocktree.add_block(block_1)
      ...> |> Blockchain.Blocktree.add_block(block_2)
      %Blockchain.Blocktree{
        block: :root,
        children: %{
          <<1>> => %Blockchain.Blocktree{
            block: %Blockchain.Block{block_hash: <<1>>, header: %Block.Header{difficulty: 100, number: 5, parent_hash: <<0::256>>}},
            children: %{
              <<2>> =>
                %Blockchain.Blocktree{
                  block: %Blockchain.Block{block_hash: <<2>>, header: %Block.Header{difficulty: 110, number: 6, parent_hash: <<1>>}},
                  children: %{},
                  parent_map: %{},
                  total_difficulty: 110
                }
            },
            total_difficulty: 110,
            parent_map: %{},
          }
        },
        total_difficulty: 110,
        parent_map: %{
          <<1>> => <<0::256>>,
          <<2>> => <<1>>,
        }
      }
  """
  @spec add_block(t, Block.t) :: t
  def add_block(blocktree, block) do
    block_hash = block.block_hash || ( block |> Block.hash() )
    blocktree = %{blocktree | parent_map: Map.put(blocktree.parent_map, block_hash, block.header.parent_hash)}

    case get_path_to_root(blocktree, block_hash) do
      :no_path -> raise InvalidBlockError, "No path to root" # TODO: How we can better handle this case?
      {:ok, path} ->
        do_add_block(blocktree, block, block_hash, path)
    end
  end

  # Recursively walk tree and to add children block
  @spec do_add_block(t, Block.t, EVM.hash, [EVM.hash]) :: t
  defp do_add_block(blocktree, block, block_hash, path) do
    case path do
      [] ->
        tree = rooted_tree(block)
        new_children = Map.put(blocktree.children, block_hash, tree)

        %{blocktree | children: new_children, total_difficulty: max_difficulty(new_children)}
      [path_hash|rest] ->
        case blocktree.children[path_hash] do
          nil -> raise InvalidBlockError, "Invalid path to root, missing path #{inspect path_hash}" # this should be impossible unless the tree is missing nodes
          sub_tree ->
            # Recurse and update the children of this tree. Note, we may also need to adjust the total
            # difficulty of this subtree.
            new_child = do_add_block(sub_tree, block, block_hash, rest)

            # TODO: Does this parent_hash only exist at the root node?
            %{blocktree |
              children: Map.put(blocktree.children, path_hash, new_child),
              total_difficulty: max(blocktree.total_difficulty, new_child.total_difficulty),
            }
        end
    end
  end

  # Gets the maximum difficulty amoungst a set of child nodes
  @spec max_difficulty(%{EVM.hash => t}) :: integer()
  defp max_difficulty(children) do
    Enum.map(children, fn {_, child} -> child.total_difficulty end) |> Enum.max
  end

  @doc """
  Returns a path from the given block's parent all the way up to the root of the tree. This will
  raise if any node does not have a valid path to root, and runs in O(n) time with regards to the
  height of the tree.

  Because the blocktree doesn't have structure based on retrieval, we store a sheet of nodes to
  parents for each subtree. That way, we can always find the correct path the traverse the tree.

  This obviously requires us to store a significant extra amount of data about the tree.

  ## Examples

      iex> Blockchain.Blocktree.get_path_to_root(
      ...>   %Blockchain.Blocktree{parent_map: %{<<1>> => <<2>>, <<2>> => <<3>>, <<3>> => <<0::256>>}},
      ...>   <<1>>)
      {:ok, [<<3>>, <<2>>]}

      iex> Blockchain.Blocktree.get_path_to_root(
      ...>   %Blockchain.Blocktree{parent_map: %{<<20>> => <<10>>, <<10>> => <<0::256>>}},
      ...>   <<20>>)
      {:ok, [<<10>>]}

      iex> Blockchain.Blocktree.get_path_to_root(
      ...>   %Blockchain.Blocktree{parent_map: %{<<30>> => <<20>>, <<31>> => <<20>>, <<20>> => <<10>>, <<21 >> => <<10>>, <<10>> => <<0::256>>}},
      ...>   <<30>>)
      {:ok, [<<10>>, <<20>>]}

      iex> Blockchain.Blocktree.get_path_to_root(
      ...>   %Blockchain.Blocktree{parent_map: %{<<30>> => <<20>>, <<31>> => <<20>>, <<20>> => <<10>>, <<21 >> => <<10>>, <<10>> => <<0::256>>}},
      ...>   <<20>>)
      {:ok, [<<10>>]}

      iex> Blockchain.Blocktree.get_path_to_root(
      ...>   %Blockchain.Blocktree{parent_map: %{<<30>> => <<20>>, <<31>> => <<20>>, <<20>> => <<10>>, <<21 >> => <<10>>, <<10>> => <<0::256>>}},
      ...>   <<31>>)
      {:ok, [<<10>>, <<20>>]}

      iex> Blockchain.Blocktree.get_path_to_root(
      ...>   %Blockchain.Blocktree{parent_map: %{<<30>> => <<20>>, <<31>> => <<20>>, <<20>> => <<10>>, <<21 >> => <<10>>, <<10>> => <<0::256>>}},
      ...>   <<32>>)
      :no_path
  """
  @spec get_path_to_root(t, EVM.hash) :: {:ok, [EVM.hash]} | :no_path
  def get_path_to_root(blocktree, hash) do
    case do_get_path_to_root(blocktree, hash) do
      {:ok, path} -> {:ok, Enum.reverse(path)}
      els -> els
    end
  end

  @spec do_get_path_to_root(t, EVM.hash) :: {:ok, [EVM.hash]} | :no_path
  defp do_get_path_to_root(blocktree, hash) do
    case Map.get(blocktree.parent_map, hash, :no_path) do
      :no_path -> :no_path
      <<0::256>> -> {:ok, []}
      parent_hash -> case do_get_path_to_root(blocktree, parent_hash) do
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

  # TODO: Add examples
  """
  @spec inspect_tree(t) :: [any()]
  def inspect_tree(blocktree) do
    value = case blocktree.block do
      :root -> :root
      block -> {block.header.number, block.block_hash}
    end

    children = for {_, child} <- blocktree.children, do: inspect_tree(child)

    [value | children]
  end

end