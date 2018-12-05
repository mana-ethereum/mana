defmodule ExWire.Bridge.Sync do
  @moduledoc """
  Wrapper for the Sync process to gracefully handle interactions with it when it
  is not running.
  """

  alias Blockchain.Block
  alias Blockchain.Blocktree
  alias Blockchain.Chain
  alias ExWire.Sync
  alias MerklePatriciaTree.Trie

  @spec get_best_block_and_chain() :: {:ok, Block.t(), Chain.t()} | {:error, atom()}
  def get_best_block_and_chain() do
    case get_last_sync_state() do
      {:ok, state} ->
        {:ok, block} = get_best_block({:ok, state})
        {:ok, chain} = get_chain({:ok, state})
        {:ok, block, chain}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec get_best_block(Sync.state() | any()) :: {:ok, Block.t()} | {:error, atom()}
  def get_best_block(sync_state \\ nil) do
    case sync_state || get_last_sync_state() do
      {:ok, state} ->
        {:ok, {block, _caching_trie}} =
          Blocktree.get_best_block(state.block_tree, state.chain, state.trie)

        {:ok, block}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec get_chain(Sync.state() | any()) :: {:ok, Chain.t()} | {:error, atom()}
  def get_chain(sync_state \\ nil) do
    case sync_state || get_last_sync_state() do
      {:ok, state} ->
        {:ok, state.chain}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec get_current_trie(Sync.state() | any()) :: {:ok, Trie.t()} | {:error, atom()}
  def get_current_trie(sync_state \\ nil) do
    case sync_state || get_last_sync_state() do
      {:ok, state} ->
        {:ok, state.trie}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec get_last_sync_state() :: {:ok, Sync.state()} | {:error, :sync_not_running}
  defp get_last_sync_state() do
    case Process.whereis(Sync) do
      nil ->
        {:error, :sync_not_running}

      _ ->
        {:ok, Sync.get_state()}
    end
  end
end
