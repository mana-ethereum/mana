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

  @word_size_in_bytes 4
  @byte_size 8
  @int_size 256
  @address_size 160
  @max_int round(:math.pow(2, @int_size))
  @max_address round(:math.pow(2, @address_size))

  @doc """
  Returns maximum allowed integer size.
  """
  def max_int(), do: @max_int
  def int_size(), do: @int_size
  def byte_size(), do: @byte_size

  @doc """
  Returns word size in bits.
  """
  def word_size(), do: @word_size_in_bytes * @byte_size

  @doc """
  Returns the maximum allowed address size.
  """
  def address_size, do: @address_size
  @doc """
  Returns the maximum allowed address value.
  """
  def max_address, do: @max_address

end
