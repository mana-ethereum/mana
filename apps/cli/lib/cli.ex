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

  @doc """
  Initiates a sync with a given provider (e.g. a JSON-RPC client, such
  as Infura). This is the basis of our "sync the blockchain" code.
  """
  def sync(sync_provider \\ CLI.Sync.Infura, provider_args \\ []) do
    db = MerklePatriciaTree.DB.RocksDB.init(db_name())
    chain = Blockchain.Chain.load_chain(:foundation)

    {:ok, provider_state} = apply(sync_provider, :setup, provider_args)

    # First, try to load tree from local database
    tree =
      case MerklePatriciaTree.DB.get(db, "current_block_tree") do
        {:ok, current_block_tree} ->
          :erlang.binary_to_term(current_block_tree)

        _ ->
          Blockchain.Blocktree.new_tree()
      end

    current_block =
      case tree.best_block do
        nil ->
          Blockchain.Genesis.create_block(chain, db)

        block ->
          {:ok, current_block} = Blockchain.Block.get_block(block.block_hash, db)

          current_block
      end

    sync_provider.add_block_to_tree(provider_state, db, chain, tree, current_block.header.number)
  end

  # The name of the database (e.g. for RocksDB) to store loaded blocks in.
  @spec db_name() :: String.t()
  defp db_name() do
    env = Mix.env() |> to_string()
    "db/mana-" <> env
  end
end
