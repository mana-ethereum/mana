defmodule CLI do
  @moduledoc """
  Command-line tooling for Mana.

  We currently support syncing via the CLI, run as:

  ```bash
  mana> mix sync --provider-url https://mainnet.infura.io/...
  ```

  Over time, with releases, we plan to evolve the CLI to function
  similar to Parity, so you may see:

  ```bash
  ./mana --sync --rpc --submit-transaction "{...}"
  ```
  """
  alias Blockchain.{Block, Blocktree, Chain, Genesis}
  alias CLI.Config
  alias MerklePatriciaTree.DB
  alias MerklePatriciaTree.DB.RocksDB

  @doc """
  Initiates a sync with a given provider (e.g. a JSON-RPC client, such
  as Infura). This is the basis of our "sync the blockchain" code.
  """
  def sync(chain_id, sync_provider, provider_args \\ []) do
    db = RocksDB.init(Config.db_name(chain_id))
    chain = Chain.load_chain(chain_id)

    {:ok, provider_state} = apply(sync_provider, :setup, provider_args)

    # First, try to load tree from local database
    tree =
      case DB.get(db, "current_block_tree") do
        {:ok, current_block_tree} ->
          :erlang.binary_to_term(current_block_tree)

        _ ->
          Blocktree.new_tree()
      end

    current_block =
      case tree.best_block do
        nil ->
          Genesis.create_block(chain, db)

        block ->
          {:ok, current_block} = Block.get_block(block.block_hash, db)

          current_block
      end

    sync_provider.add_block_to_tree(provider_state, db, chain, tree, current_block.header.number)
  end
end
