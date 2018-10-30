defmodule CLI do
  @moduledoc """
  Command-line tooling for Mana. We currently expose a function
  to kick off syncing with a remote RPC client.
  """
  require Logger

  alias Blockchain.{Blocktree, Chain}
  alias CLI.{Config, State, Sync}
  alias MerklePatriciaTree.DB.RocksDB

  @doc """
  Initiates a sync with a given provider (e.g. a JSON-RPC client, such
  as Infura). This is the basis of our "sync the blockchain" code.
  """
  @spec sync(atom(), module(), [any()]) :: {:ok, Blocktree.t()} | {:error, any()}
  def sync(chain_id, block_provider, block_provider_args \\ []) do
    db = RocksDB.init(Config.db_name(chain_id))
    chain = Chain.load_chain(chain_id)

    {:ok, block_provider_state} = apply(block_provider, :setup, block_provider_args)

    tree = State.load_tree(db)

    with {:ok, current_block} <- Blocktree.get_best_block(tree, chain, db) do
      with {:ok, highest_known_block_number} <-
             block_provider.get_block_number(block_provider_state) do
        # Note: we load the highest block number right now just
        # to track our progress.

        Logger.info(fn ->
          "Starting sync at block ##{current_block.header.number} of #{highest_known_block_number} total blocks"
        end)

        # TODO: Use highest known block as limit?

        Sync.sync_new_blocks(
          block_provider,
          block_provider_state,
          db,
          chain,
          tree,
          current_block.header.number + 1,
          :infinite,
          highest_known_block_number
        )
      end
    end
  end
end
