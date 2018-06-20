defmodule EVM do
  @moduledoc """
  Documentation for EVM.
  """

  # σ[a]
  @type account :: %{
          # σ[a]_n
          nonce: integer(),
          # σ[a]_b
          balance: integer(),
          # σ[a]_s
          storage: MerklePatriciaTree.Trie.t(),
          # σ[a]_c
          code: binary()
        }
  # σ
  @type state :: %{address() => account()}
  @type trie_root :: MerklePatriciaTree.Trie.root_hash()
  @type val :: integer()
  @type address :: <<_::160>>
  @type hash :: <<_::256>>
  @type timestamp :: integer()
end
