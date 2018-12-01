defmodule Blockchain.BlockSetter do
  @moduledoc """
  This module is a utility module that performs setters on a block struct.
  """

  alias Block.Header
  alias Blockchain.Block
  alias Blockchain.BlockGetter
  alias Blockchain.Chain
  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.TrieStorage

  @doc """
  Calculates the `number` for a new block. This implements Eq.(38) from
  the Yellow Paper.

  ## Examples

      iex> Blockchain.Block.set_block_number(%Blockchain.Block{header: %Block.Header{extra_data: "hello"}}, %Blockchain.Block{header: %Block.Header{number: 32}})
      %Blockchain.Block{header: %Block.Header{number: 33, extra_data: "hello"}}

      iex> Blockchain.Block.set_block_number(%Blockchain.Block{header: %Block.Header{extra_data: "hello"}}, %Blockchain.Block{header: %Block.Header{number: nil}})
      %Blockchain.Block{header: %Block.Header{number: nil, extra_data: "hello"}}
  """
  @spec set_block_number(Block.t(), Block.t()) :: Block.t()
  def set_block_number(block, %Block{header: %Header{number: nil}}) do
    %{block | header: %{block.header | number: nil}}
  end

  def set_block_number(block, %Block{header: %Header{number: parent_block_number}})
      when is_integer(parent_block_number) do
    %{block | header: %{block.header | number: parent_block_number + 1}}
  end

  @doc """
  Set the difficulty of a new block based on Eq.(39), better defined
  in `Block.Header`.

  # TODO: Validate these results

  ## Examples

      iex> Blockchain.Block.set_block_difficulty(
      ...>   %Blockchain.Block{header: %Block.Header{number: 0, timestamp: 0}},
      ...>   Blockchain.Test.ropsten_chain(),
      ...>   nil
      ...> )
      %Blockchain.Block{header: %Block.Header{number: 0, timestamp: 0, difficulty: 1_048_576}}

      iex> Blockchain.Block.set_block_difficulty(
      ...>   %Blockchain.Block{header: %Block.Header{number: 1, timestamp: 1_479_642_530}},
      ...>   Blockchain.Test.ropsten_chain(),
      ...>   %Blockchain.Block{header: %Block.Header{number: 0, timestamp: 0, difficulty: 1_048_576}}
      ...> )
      %Blockchain.Block{header: %Block.Header{number: 1, timestamp: 1_479_642_530, difficulty: 997_888}}
  """
  @spec set_block_difficulty(Block.t(), Chain.t(), Block.t()) :: Block.t()
  def set_block_difficulty(block, chain, parent_block) do
    difficulty = BlockGetter.get_difficulty(block, parent_block, chain)

    %{block | header: %{block.header | difficulty: difficulty}}
  end

  @doc """
  Sets the gas limit of a given block, or raises
  if the block limit is not acceptable. The validity
  check is defined in Eq.(45), Eq.(46) and Eq.(47) of
  the Yellow Paper.

  ## Examples

      iex> Blockchain.Block.set_block_gas_limit(
      ...>   %Blockchain.Block{header: %Block.Header{}},
      ...>   Blockchain.Test.ropsten_chain(),
      ...>   %Blockchain.Block{header: %Block.Header{gas_limit: 1_000_000}},
      ...>   1_000_500
      ...> )
      %Blockchain.Block{header: %Block.Header{gas_limit: 1_000_500}}

      iex> Blockchain.Block.set_block_gas_limit(
      ...>   %Blockchain.Block{header: %Block.Header{}},
      ...>   Blockchain.Test.ropsten_chain(),
      ...>   %Blockchain.Block{header: %Block.Header{gas_limit: 1_000_000}},
      ...>   2_000_000
      ...> )
      ** (RuntimeError) Block gas limit not valid
  """
  @spec set_block_gas_limit(Block.t(), Chain.t(), Block.t(), EVM.Gas.t()) :: Block.t()
  def set_block_gas_limit(block, chain, parent_block, gas_limit) do
    if not Header.is_gas_limit_valid?(
         gas_limit,
         parent_block.header.gas_limit,
         chain.params[:gas_limit_bound_divisor],
         chain.params[:min_gas_limit]
       ),
       do: raise("Block gas limit not valid")

    %{block | header: %{block.header | gas_limit: gas_limit}}
  end

  @doc """
  Sets block's parent's hash
  """
  @spec set_block_parent_hash(Block.t(), Block.t()) :: Block.t()
  def set_block_parent_hash(block, parent_block) do
    parent_hash = parent_block.block_hash || Block.hash(parent_block)
    header = %{block.header | parent_hash: parent_hash}
    %{block | header: header}
  end

  @doc """
  Sets the state_root of a given block from a trie.

  ## Examples
      iex> trie = %MerklePatriciaTree.Trie{root_hash: <<5::256>>, db: {MerklePatriciaTree.DB.ETS, :get_state}}
      iex> Blockchain.Block.set_state(%Blockchain.Block{}, trie)
      %Blockchain.Block{header: %Block.Header{state_root: <<5::256>>}}
  """
  @spec set_state(Block.t(), Trie.t()) :: Block.t()
  def set_state(block, trie) do
    root_hash = TrieStorage.root_hash(trie)

    put_header(block, :state_root, root_hash)
  end

  '''
  Sets a given block header field as a shortcut when
  we want to change a single field.
  '''

  @spec put_header(Block.t(), any(), any()) :: Block.t()
  defp put_header(block, key, value) do
    new_header = Map.put(block.header, key, value)
    %{block | header: new_header}
  end
end
