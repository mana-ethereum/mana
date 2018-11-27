defmodule ExWire.BridgeSyncMock do
  @moduledoc """
  GenServer to mimic the behaviour of the real Sync server, meant to
  reduce dependencies in tests that rely on Sync.
  """
  use GenServer

  def get_best_block_and_chain() do
    {block_status, block} = get_best_block()
    {chain_status, chain} = get_chain()

    case {block_status, chain_status} do
      {:error, _} -> {:error, block}
      {_, :error} -> {:error, chain}
      _ -> {:ok, block, chain}
    end
  end

  def set_best_block(block) do
    GenServer.call(get_process_name(), {:set_best_block, block})
  end

  def get_best_block() do
    get_with_running_check(:get_best_block)
  end

  def set_chain(chain) do
    GenServer.call(get_process_name(), {:set_chain, chain})
  end

  def get_chain() do
    get_with_running_check(:get_chain)
  end

  def set_current_trie(trie) do
    GenServer.call(get_process_name(), {:set_current_trie, trie})
  end

  def get_current_trie() do
    get_with_running_check(:get_current_trie)
  end

  def get_with_running_check(key) do
    case Process.whereis(get_process_name()) do
      nil ->
        {:error, :sync_not_running}

      _ ->
        GenServer.call(get_process_name(), key)
    end
  end

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: get_process_name())
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
  def handle_call({:set_chain, chain}, _, state) do
    {:reply, :ok, Map.put(state, :chain, chain)}
  end

  @impl true
  def handle_call(:get_chain, _, state) do
    {:reply, {:ok, state.chain}, state}
  end

  @impl true
  def handle_call({:set_current_trie, trie}, _, state) do
    {:reply, :ok, Map.put(state, :current_trie, trie)}
  end

  @impl true
  def handle_call(:get_current_trie, _, state) do
    {:reply, {:ok, state.current_trie}, state}
  end

  defp get_process_name() do
    String.to_atom(":#{Kernel.inspect(self())}_sync_mock")
  end
end
