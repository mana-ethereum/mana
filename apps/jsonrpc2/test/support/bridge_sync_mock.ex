defmodule JSONRPC2.BridgeSyncMock do
  alias Blockchain.Block
  alias JSONRPC2.Response.Block, as: ResponseBlock
  alias JSONRPC2.Struct.EthSyncing

  use GenServer

  def connected_peer_count() do
    GenServer.call(__MODULE__, :connected_peer_count)
  end

  def set_connected_peer_count(connected_peer_count) do
    GenServer.call(__MODULE__, {:set_connected_peer_count, connected_peer_count})
  end

  def get_last_sync_block_stats() do
    GenServer.call(__MODULE__, :get_last_sync_block_stats)
  end

  def set_last_sync_block_stats(block_stats) do
    GenServer.call(__MODULE__, {:set_last_sync_block_stats, block_stats})
  end

  def put_block(block) do
    GenServer.call(__MODULE__, {:put_block, block})
  end

  def get_block_by_number(number) do
    GenServer.call(__MODULE__, {:get_block_by_number, number})
  end

  def get_block_by_hash(hash) do
    GenServer.call(__MODULE__, {:get_block_by_hash, hash})
  end

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def init(state) do
    {:ok, state}
  end

  def handle_call(:connected_peer_count, _, state) do
    {:reply, state.connected_peer_count, state}
  end

  def handle_call({:set_connected_peer_count, connected_peer_count}, _, state) do
    {:reply, :ok, Map.put(state, :connected_peer_count, connected_peer_count)}
  end

  def handle_call({:put_block, block}, _, state = %{trie: trie}) do
    {:ok, {_, updated_trie}} = Block.put_block(block, trie, block.block_hash)
    updated_state = %{state | trie: updated_trie}

    {:reply, :ok, updated_state}
  end

  def handle_call({:get_block_by_number, number}, _, state = %{trie: trie}) do
    block =
      case Block.get_block_with_additional_info(number, trie) do
        {:ok, block} -> ResponseBlock.new(block)
        _ -> nil
      end

    {:reply, block, state}
  end

  def handle_call({:get_block_by_hash, hash}, _, state = %{trie: trie}) do
    block =
      case Block.get_block_with_additional_info(hash, trie) do
        {:ok, block} -> ResponseBlock.new(block)
        _ -> nil
      end

    {:reply, block, state}
  end

  @spec handle_call(:get_last_sync_block_stats, {pid, any}, map()) ::
          {:reply, EthSyncing.output(), map()}
  def handle_call(:get_last_sync_block_stats, _, state) do
    {:reply, state.block_stats, state}
  end

  @spec handle_call(
          {:set_last_sync_block_stats, EthSyncing.input()},
          {pid, any},
          map()
        ) :: {:reply, :ok, map()}
  def handle_call({:set_last_sync_block_stats, block_stats}, _, state) do
    new_state = Map.put(state, :block_stats, block_stats)
    {:reply, :ok, new_state}
  end
end
