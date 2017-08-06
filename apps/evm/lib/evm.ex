defmodule EVM do
  @moduledoc """
  Documentation for EVM.
  """

  @type state :: MerklePatriciaTree.Trie.t
  @type trie_root :: MerklePatriciaTree.Trie.root_hash
  @type val :: integer()
  @type address :: <<_::160>>
  @type hash :: <<_::256>>
  @type timestamp :: integer()

  @max_int round(:math.pow(2, 256))

  @doc """
  Returns maximum allowed integer size.
  """
  def max_int(), do: @max_int

end
