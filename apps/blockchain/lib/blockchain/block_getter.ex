defmodule Blockchain.BlockGetter do
  @moduledoc """
  This module is a utility module that performs getters on a block struct or calculations based on the block.
  """
  alias Block.Header
  alias Blockchain.Block
  alias Blockchain.Chain
  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.TrieStorage

  @doc """
  Returns a trie rooted at the state_root of a given block.

  ## Examples

      iex> db = MerklePatriciaTree.Test.random_ets_db(:get_state)
      iex> Blockchain.BlockGetter.get_state(%Blockchain.Block{header: %Block.Header{state_root: <<5::256>>}}, MerklePatriciaTree.Trie.new(db))
      %MerklePatriciaTree.Trie{root_hash: <<5::256>>, db: {MerklePatriciaTree.DB.ETS, :get_state}}
  """
  @spec get_state(Block.t(), TrieStorage.t()) :: Trie.t()
  def get_state(block, trie) do
    TrieStorage.set_root_hash(trie, block.header.state_root)
  end

  def get_difficulty(block, parent_block, chain) do
    cond do
      Chain.after_bomb_delays?(chain, block.header.number) ->
        delay_factor = Chain.bomb_delay_factor_for_block(chain, block.header.number)

        Header.get_byzantium_difficulty(
          block.header,
          if(parent_block, do: parent_block.header, else: nil),
          delay_factor,
          chain.genesis[:difficulty],
          chain.engine["Ethash"][:minimum_difficulty],
          chain.engine["Ethash"][:difficulty_bound_divisor]
        )

      Chain.after_homestead?(chain, block.header.number) ->
        Header.get_homestead_difficulty(
          block.header,
          if(parent_block, do: parent_block.header, else: nil),
          chain.genesis[:difficulty],
          chain.engine["Ethash"][:minimum_difficulty],
          chain.engine["Ethash"][:difficulty_bound_divisor]
        )

      true ->
        Header.get_frontier_difficulty(
          block.header,
          if(parent_block, do: parent_block.header, else: nil),
          chain.genesis[:difficulty],
          chain.engine["Ethash"][:minimum_difficulty],
          chain.engine["Ethash"][:difficulty_bound_divisor]
        )
    end
  end
end
