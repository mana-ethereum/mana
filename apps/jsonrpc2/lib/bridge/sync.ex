defmodule JSONRPC2.Bridge.Sync do
  alias Blockchain.Blocktree
  alias Blockchain.Block
  alias ExWire.PeerSupervisor
  alias ExWire.Sync

  @spec connected_peer_count :: 0 | non_neg_integer()
  def connected_peer_count, do: PeerSupervisor.connected_peer_count()

  @spec get_last_sync_block_stats() ::
          {non_neg_integer(), non_neg_integer(), non_neg_integer()} | false
  def get_last_sync_block_stats() do
    case Process.whereis(Sync) do
      nil ->
        false

      _ ->
        state = get_last_sync_state()

        {:ok, {block, _caching_trie}} =
          Blocktree.get_best_block(state.block_tree, state.chain, state.trie)

        {block.header.number, state.starting_block_number, state.highest_block_number}
    end
  end

  @spec get_last_sync_state() :: Sync.state()
  defp get_last_sync_state(), do: Sync.get_state()

  @spec get_block_by_number(integer()) :: nil | Block.t()
  def get_block_by_number(number) do
    state_trie = get_last_sync_state().trie

    case Block.get_block_by_number(number, state_trie) do
      {:ok, block} -> block
      _ -> nil
    end
  end
end
