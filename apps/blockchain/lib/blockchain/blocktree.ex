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
            best_block: nil,
            parent_map: %{}

  @type t :: %__MODULE__{
          block: :root | Block.t(),
          children: %{EVM.hash() => t},
          total_difficulty: integer(),
          best_block: Block.t() | nil,
          parent_map: %{EVM.hash() => EVM.hash()}
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

  # Creates a new trie with a given root.
  # This should be used to create sub-trees internally.
  @spec rooted_tree(Block.t()) :: t
  defp rooted_tree(gen_block) do
    %__MODULE__{
      block: gen_block,
      children: %{},
      total_difficulty: gen_block.header.difficulty,
      parent_map: %{}
    }
  end

  @doc """
  Verifies a block is valid, and if so, adds it to the block tree.
  This performs four steps.

  1. Find the parent block
  2. Verfiy the block against its parent block
  3. If valid, put the block into our DB
  4. Add the block to our blocktree.

  ## Examples

      # For a genesis block
      iex> trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      iex> chain = Blockchain.Chain.load_chain(:ropsten)
      iex> gen_block = %Blockchain.Block{header: %Block.Header{number: 0, parent_hash: <<0::256>>, beneficiary: <<2, 3, 4>>, difficulty: 0x100000, gas_limit: 0x1000000, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>, state_root: <<33, 123, 11, 188, 251, 114, 226, 213, 126, 40, 243, 60, 179, 97, 185, 152, 53, 19, 23, 119, 85, 220, 63, 51, 206, 62, 112, 34, 237, 98, 183, 123>>}}
      iex> tree = Blockchain.Blocktree.new_tree()
      iex> {:ok, tree_1} = Blockchain.Blocktree.verify_and_add_block(tree, chain, gen_block, trie.db)
      iex> Blockchain.Blocktree.inspect_tree(tree_1)
      [:root, [{0, <<71, 157, 104, 174, 116, 127, 80, 187, 43, 230, 237, 165, 124,
                     115, 132, 188, 112, 248, 218, 117, 191, 179, 180, 121, 118, 244,
                     128, 207, 39, 194, 241, 152>>}]]

      # With a valid block
      iex> trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      iex> chain = Blockchain.Chain.load_chain(:ropsten)
      iex> parent = Blockchain.Genesis.create_block(chain, trie.db)
      iex> child = Blockchain.Block.gen_child_block(parent, chain)
      iex> block_1 = %Blockchain.Block{header: %Block.Header{number: 0, parent_hash: <<0::256>>, beneficiary: <<2, 3, 4>>, difficulty: 1_048_576, timestamp: 0, gas_limit: 200_000, mix_hash: <<1>>, nonce: <<2>>, state_root: parent.header.state_root}}
      iex> block_2 = %Blockchain.Block{header: %Block.Header{number: 1, parent_hash: block_1 |> Blockchain.Block.hash, beneficiary: <<2::160>>, difficulty: 997_888, timestamp: 1_479_642_530, gas_limit: 200_000, mix_hash: <<1>>, nonce: <<2>>, state_root: child.header.state_root}} |> Blockchain.Block.add_rewards(trie.db, chain)
      iex> tree = Blockchain.Blocktree.new_tree()
      iex> {:ok, tree_1} = Blockchain.Blocktree.verify_and_add_block(tree, chain, block_1, trie.db)
      iex> {:ok, tree_2} = Blockchain.Blocktree.verify_and_add_block(tree_1, chain, block_2, trie.db)
      iex> Blockchain.Blocktree.inspect_tree(tree_2)
      [:root,
            [{0,
              <<155, 169, 162, 94, 229, 198, 27, 192, 121, 15, 154, 160, 41, 76,
                199, 62, 154, 57, 121, 20, 34, 43, 200, 107, 54, 247, 204, 195,
                57, 60, 223, 204>>},
             [{1,
               <<46, 192, 123, 64, 63, 230, 19, 10, 150, 191, 251, 157, 226, 35,
                 183, 69, 92, 177, 33, 66, 159, 174, 200, 202, 197, 69, 24, 216,
                 9, 107, 151, 192>>}]]]

      # With a invalid block
      iex> trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      iex> chain = Blockchain.Chain.load_chain(:ropsten)
      iex> parent = Blockchain.Genesis.create_block(chain, trie.db)
      iex> block_1 = %Blockchain.Block{header: %Block.Header{number: 0, parent_hash: <<0::256>>, beneficiary: <<2, 3, 4>>, difficulty: 1_048_576, timestamp: 11, gas_limit: 200_000, mix_hash: <<1>>, nonce: <<2>>, state_root: parent.header.state_root}}
      iex> block_2 = %Blockchain.Block{header: %Block.Header{number: 1, parent_hash: block_1 |> Blockchain.Block.hash, beneficiary: <<2, 3, 4>>, difficulty: 110, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}}
      iex> tree = Blockchain.Blocktree.new_tree()
      iex> {:ok, tree_1} = Blockchain.Blocktree.verify_and_add_block(tree, chain, block_1, trie.db)
      iex> Blockchain.Blocktree.verify_and_add_block(tree_1, chain, block_2, trie.db)
      {:invalid, [:invalid_difficulty, :invalid_gas_limit, :child_timestamp_invalid]}
  """
  @spec verify_and_add_block(t, Chain.t(), Block.t(), MerklePatriciaTree.DB.db(), boolean()) ::
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
        best_block: %Blockchain.Block{block_hash: <<2>>, header: %Block.Header{difficulty: 110, number: 6, parent_hash: <<1>>}},
        parent_map: %{
          <<1>> => <<0::256>>,
          <<2>> => <<1>>,
        }
      }
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
        blocktree
        |> do_add_block(block, block_hash, path)
        |> update_best_block(block)
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

  # Recursively walk tree and to add children block
  @spec do_add_block(t, Block.t(), EVM.hash(), [EVM.hash()]) :: t
  defp do_add_block(blocktree, block, block_hash, path) do
    case path do
      [] ->
        tree = rooted_tree(block)
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
    children |> Enum.map(fn {_, child} -> child.total_difficulty end) |> Enum.max()
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

  ## Examples

      iex> Blockchain.Blocktree.new_tree()
      ...> |> Blockchain.Blocktree.add_block(%Blockchain.Block{block_hash: <<1>>, header: %Block.Header{number: 0, parent_hash: <<0::256>>, difficulty: 100}})
      ...> |> Blockchain.Blocktree.add_block(%Blockchain.Block{block_hash: <<2>>, header: %Block.Header{number: 1, parent_hash: <<0::256>>, difficulty: 110}})
      ...> |> Blockchain.Blocktree.add_block(%Blockchain.Block{block_hash: <<3>>, header: %Block.Header{number: 2, parent_hash: <<0::256>>, difficulty: 120}})
      ...> |> Blockchain.Blocktree.inspect_tree()
      [:root, [{0, <<1>>}], [{1, <<2>>}], [{2, <<3>>}]]
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
