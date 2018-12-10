defmodule JSONRPC2.TestFactory do
  alias Block.Header
  alias Blockchain.Block
  alias Blockchain.Transaction

  @empty_trie MerklePatriciaTree.Trie.empty_trie_root_hash()

  def build(factory_sym, opts \\ []) do
    args = Enum.into(opts, %{})

    factory(factory_sym, args)
  end

  def factory(:block, opts) do
    defaults = %{
      block_hash: <<0x10::256>>,
      header: build(:header),
      transactions: [],
      receipts: [],
      ommers: []
    }

    args = Map.merge(defaults, opts)

    struct!(Block, args)
  end

  def factory(:header, opts) do
    defaults = %{
      parent_hash: <<0x10::256>>,
      ommers_hash: <<0x10::256>>,
      beneficiary: <<0x10::160>>,
      state_root: @empty_trie,
      transactions_root: @empty_trie,
      receipts_root: @empty_trie,
      logs_bloom: <<0::2048>>,
      difficulty: 1,
      number: 1,
      gas_limit: 0,
      gas_used: 0,
      timestamp: 1,
      extra_data: <<>>,
      mix_hash: <<0::256>>,
      nonce: <<0::64>>
    }

    args = Map.merge(defaults, opts)

    struct!(Header, args)
  end

  def factory(:transaction, opts) do
    defaults = %{
      nonce: 0,
      gas_price: 0,
      gas_limit: 0,
      to: <<0x10::160>>,
      value: 0,
      r: 0,
      v: 0,
      s: 1,
      init: <<>>,
      data: <<>>
    }

    args = Map.merge(defaults, opts)

    struct(Transaction, args)
  end
end
