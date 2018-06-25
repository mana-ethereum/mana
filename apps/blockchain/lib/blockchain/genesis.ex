defmodule Blockchain.Genesis do
  @moduledoc """
  Defines functions for genesis block generation.
  """

  alias EthCore.Block.Header
  alias Blockchain.{Block, Account, Chain}
  alias MerklePatriciaTree.{Trie, DB}

  @type seal_config :: %{
          mix_hash: binary(),
          nonce: binary()
        }

  @type seal :: %{String.t() => seal_config()}

  @type t :: %{
          seal: nil | seal(),
          difficulty: integer(),
          author: EVM.address(),
          timestamp: integer(),
          parent_hash: EVM.hash(),
          extra_data: binary(),
          gas_limit: EVM.Gas.t()
        }

  @doc """
  Creates a genesis block for a given chain.

  The genesis block is specified by parameters in the chain itself.
  Thus, this function takes no additional parameters.
  """
  @spec new_block(Chain.t(), DB.db()) :: Block.t()
  def new_block(chain, db) do
    header = create_header(chain.genesis)
    block = %Block{header: header}
    accounts = Enum.into(chain.accounts, [])

    state =
      Enum.reduce(accounts, Trie.new(db), fn {address, account_map}, trie ->
        account = create_account(db, address, account_map)
        Account.put_account(trie, address, account)
      end)

    header = %{header | state_root: state.root_hash}

    %{block | header: header}
  end

  @doc """
  Creates a genesis block header.
  """
  @spec create_header(t) :: Header.t()
  def create_header(genesis) do
    %Header{
      number: 0,
      parent_hash: genesis[:parent_hash],
      timestamp: genesis[:timestamp],
      extra_data: genesis[:extra_data],
      beneficiary: genesis[:author],
      difficulty: genesis[:difficulty],
      gas_limit: genesis[:gas_limit],
      mix_hash: genesis[:seal][:ethereum][:mix_hash],
      nonce: genesis[:seal][:ethereum][:nonce]
    }
  end

  @spec create_account(DB.db(), EVM.address(), map()) :: Account.t()
  def create_account(db, address, account_map) do
    storage =
      if account_map[:storage_root],
        do: Trie.new(db, account_map[:storage_root]),
        else: Trie.new(db)

    storage =
      if account_map[:storage] do
        Enum.reduce(account_map[:storage], storage, fn {key, value}, trie ->
          Account.put_storage(trie, address, key, value)
        end)
      else
        storage
      end

    %Account{
      nonce: account_map[:nonce] || 0,
      balance: account_map[:balance],
      storage_root: storage.root_hash
    }
  end
end
