defmodule ExWire.BridgeSyncMock do
  @moduledoc """
  GenServer to mimic the behaviour of the real Sync server, meant to
  reduce dependencies in tests that rely on Sync.
  """
  use GenServer

  def set_best_block(block) do
    GenServer.call(__MODULE__, {:set_best_block, block})
  end

  def get_best_block() do
    get_with_running_check(:get_best_block)
  end

  def set_current_trie(trie) do
    GenServer.call(__MODULE__, {:set_current_trie, trie})
  end

  def get_current_trie() do
    get_with_running_check(:get_current_trie)
  end

  def get_with_running_check(key) do
    case Process.whereis(__MODULE__) do
      nil ->
        {:error, :sync_not_running}

      _ ->
        GenServer.call(__MODULE__, key)
    end
  end

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:set_best_block, block}, _, state) do
    {:reply, :ok, Map.put(state, :best_block, block)}
  end

  @impl true
  def handle_call(:get_best_block, _, state) do
    {:reply, {:ok, state.best_block}, state}
  end

  @impl true
  def handle_call({:set_current_trie, trie}, _, state) do
    {:reply, :ok, Map.put(state, :current_trie, trie)}
  end

  @impl true
  def handle_call(:get_current_trie, _, state) do
    {:reply, {:ok, state.current_trie}, state}
  end
end
