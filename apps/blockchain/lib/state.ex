defmodule Blockchain.State do
  @moduledoc """
  Blockchain.State keeps track of local state, e.g. the blockchain
  which we have synced so far.
  """
  require Logger

  alias Blockchain.Blocktree
  alias MerklePatriciaTree.DB

  @doc """
  Loads the current block tree from the database.
  """
  @spec load_tree(DB.db()) :: Blocktree.t()
  def load_tree(db) do
    case DB.get(db, "current_block_tree") do
      {:ok, current_block_tree} ->
        :erlang.binary_to_term(current_block_tree)

      :not_found ->
        Blocktree.new_tree()
    end
  end

  @doc """
  Stores the current block tree into the database.
  """
  @spec save_tree(DB.db(), Blocktree.t()) :: :ok
  def save_tree(db, tree) do
    :ok = Logger.info(fn -> "Saving progress at block #{tree.best_block.header.number}" end)

    DB.put!(
      db,
      "current_block_tree",
      :erlang.term_to_binary(tree)
    )

    :ok
  end
end
