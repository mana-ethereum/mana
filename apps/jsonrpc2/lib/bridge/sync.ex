defmodule JSONRPC2.Bridge.Sync do
  alias Blockchain.Blocktree
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
end
