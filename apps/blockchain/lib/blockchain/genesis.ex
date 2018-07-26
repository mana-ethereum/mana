defmodule Blockchain.Genesis do
  @moduledoc """
  Defines functions for genesis block generation.
  """

  alias Block.Header
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

  The genesis block is specified by parameters in the
  chain itself. Thus, this function takes no additional
  parameters.

  ## Examples

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> chain = Blockchain.Chain.load_chain(:ropsten)
      iex> Blockchain.Genesis.create_block(chain, db)
      %Blockchain.Block{
        header: %Block.Header{
          number: 0,
          timestamp: 0,
          beneficiary: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
          difficulty: 1048576,
          extra_data: "55555555555555555555555555555555",
          gas_limit: 16777216,
          parent_hash: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
          state_root: <<33, 123, 11, 188, 251, 114, 226, 213, 126, 40, 243, 60, 179, 97, 185, 152, 53, 19, 23, 119, 85, 220, 63, 51, 206, 62, 112, 34, 237, 98, 183, 123>>,
          transactions_root: <<86, 232, 31, 23, 27, 204, 85, 166, 255, 131, 69, 230, 146, 192, 248, 110, 91, 72, 224, 27, 153, 108, 173, 192, 1, 98, 47, 181, 227, 99, 180, 33>>,
          receipts_root: <<86, 232, 31, 23, 27, 204, 85, 166, 255, 131, 69, 230, 146, 192, 248, 110, 91, 72, 224, 27, 153, 108, 173, 192, 1, 98, 47, 181, 227, 99, 180, 33>>,
          ommers_hash: <<29, 204, 77, 232, 222, 199, 93, 122, 171, 133, 181, 103, 182, 204, 212, 26, 211, 18, 69, 27, 148, 138, 116, 19, 240, 161, 66, 253, 64, 212, 147, 71>>,
          mix_hash: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
          nonce: 66
        },
        ommers: [],
        transactions: []
      }

      # TODO: Add test case with initial storage
  """
  @spec create_block(Chain.t(), DB.db()) :: Block.t()
  def create_block(chain, db) do
    header = create_header(chain.genesis)
    block = %Block{header: header}
    accounts = Enum.into(chain.accounts, [])

    state =
      Enum.reduce(accounts, Trie.new(db), fn {address, account_map}, trie ->
        if is_nil(account_map[:balance]) do
          trie
        else
          account = create_account(db, address, account_map)
          Account.put_account(trie, address, account)
        end
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
      mix_hash: genesis[:seal][:mix_hash],
      nonce: genesis[:seal][:nonce]
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

  @doc """
  Returns whether or not a block is a genesis block, based on block number.

  ## Examples

      iex> Blockchain.Genesis.is_genesis_block?(%Blockchain.Block{header: %Block.Header{number: 0}})
      true

      iex> Blockchain.Genesis.is_genesis_block?(%Blockchain.Block{header: %Block.Header{number: 1}})
      false
  """
  @spec is_genesis_block?(Block.t()) :: boolean()
  def is_genesis_block?(block), do: block.header.number == 0
end
