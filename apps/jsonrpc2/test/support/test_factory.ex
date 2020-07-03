defmodule JSONRPC2.TestFactory do
  alias Block.Header
  alias Blockchain.Account
  alias Blockchain.Block
  alias Blockchain.Transaction
  alias Blockchain.Transaction.Receipt
  alias Blockchain.Transaction.Receipt.Bloom
  alias JSONRPC2.SpecHandler.CallRequest

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
      data: nil,
      gas_limit: 7,
      gas_price: 6,
      init: <<1>>,
      nonce: 5,
      r:
        38_889_131_630_470_350_300_468_726_261_158_724_183_878_062_819_625_353_581_392_042_110_782_473_464_074,
      s:
        56_013_001_490_976_921_811_414_879_795_854_011_730_332_692_343_890_561_111_314_022_658_085_426_919_315,
      to: "",
      v: 27,
      value: 5
    }

    args = Map.merge(defaults, opts)

    struct(Transaction, args)
  end

  def factory(:receipt, opts) do
    defaults = %{
      state: 1,
      cumulative_gas: 1_000,
      bloom_filter: :binary.list_to_bin(Bloom.empty()),
      logs: []
    }

    args = Map.merge(defaults, opts)

    struct(Receipt, args)
  end

  def factory(:log_entry, opts) do
    defaults = %{
      address: <<0x10::160>>,
      topics: [
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0>>,
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0>>,
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0>>,
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0>>
      ],
      data: <<1>>
    }

    args = Map.merge(defaults, opts)

    struct(EVM.LogEntry, args)
  end

  def factory(:call_request, opts) do
    defaults = %{
      from: <<0x10::160>>,
      to: <<0x11::160>>,
      gas: 10_000,
      gas_price: 1,
      value: 1,
      data: <<>>
    }

    args = Map.merge(defaults, opts)

    struct(CallRequest, args)
  end

  def factory(:account, opts) do
    defaults = %{
      nonce: 0,
      balance: 10
    }

    args = Map.merge(defaults, opts)

    struct(Account, args)
  end
end
