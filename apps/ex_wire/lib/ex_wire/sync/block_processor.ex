defmodule ExWire.Sync.BlockProcessor do
  @moduledoc """

  """
  use GenServer

  require Logger

  alias Blockchain.{Block, Blocktree, Chain}
  alias Exth.Time
  alias ExWire.Sync.BlockProcessor.StandardProcessor
  alias MerklePatriciaTree.{Trie, TrieStorage}

  @callback process_blocks(
              list(Block.t()),
              Blocktree.t(),
              backlog(),
              Chain.t(),
              Trie.t(),
              boolean()
            ) :: {list(EVM.hash()), Blocktree.t(), backlog(), Trie.t()}

  @type backlog :: %{EVM.hash() => list(Block.t())}

  @type state :: %{
          sup: pid(),
          block_processing_task: Task.t(),
          queue_blocks_messages: list(Block.t()),
          backlog: backlog(),
          trie: Trie.t()
        }

  @name __MODULE__

  @doc """
  Initializes a new BlockProcessor server.
  """
  @spec start_link({Trie.t()}, Keyword.t()) :: GenServer.on_start()
  def start_link({trie}, opts \\ []) do
    GenServer.start_link(
      __MODULE__,
      [trie: trie],
      name: Keyword.get(opts, :name, @name)
    )
  end

  @doc """
  Initializes gen server with options from `start_link`.
  """
  @impl true
  def init(trie: trie) do
    {:ok, sup} = Task.Supervisor.start_link()

    {:ok,
     %{
       sup: sup,
       block_processing_task: nil,
       queue_blocks_messages: [],
       backlog: %{},
       trie: trie
     }}
  end

  # When a task completes, we try to pull a new task from the queue.
  @spec handle_task_complete(term(), term(), state()) :: state()
  defp handle_task_complete(
         ref,
         status,
         state = %{
           sup: sup,
           trie: trie,
           backlog: backlog,
           block_processing_task: %Task{ref: task_ref},
           queue_blocks_messages: queue_blocks_messages
         }
       )
       when ref == task_ref do
    case status do
      {:ok, {:ok, next_backlog, next_trie}} ->
        %{state | backlog: next_backlog, trie: next_trie}

      :down ->
        {next_task, next_queue} =
          case queue_blocks_messages do
            [{:process_completed_blocks, pid, blocks, chain} | next_queue] ->
              task = run_task(sup, blocks, chain, pid, backlog, trie)

              {task, next_queue}

            [] ->
              {nil, []}
          end

        %{state | block_processing_task: next_task, queue_blocks_messages: next_queue}
    end
  end

  @impl true
  # Called when a task completes successfully with the return
  # value of that task.
  def handle_info({ref, msg}, state) do
    {:noreply, handle_task_complete(ref, {:ok, msg}, state)}
  end

  # Called when a task completes informing the supervisor that a child
  # has terminated normally.
  def handle_info({:DOWN, ref, :process, _pid, :normal}, state) do
    {:noreply, handle_task_complete(ref, :down, state)}
  end

  @impl true
  def handle_cast(
        {:process_completed_blocks, _pid, [], _chain},
        state
      ) do
    {:noreply, state}
  end

  def handle_cast(
        blocks_message = {:process_completed_blocks, pid, blocks, chain},
        state = %{
          sup: sup,
          trie: trie,
          backlog: backlog,
          block_processing_task: task,
          queue_blocks_messages: queue_blocks_messages
        }
      ) do
    {next_task, next_queue_blocks_messages} =
      if is_nil(task) do
        {run_task(sup, blocks, chain, pid, backlog, trie), queue_blocks_messages}
      else
        {task, [blocks_message | queue_blocks_messages]}
      end
      |> Exth.inspect("Process completed blocks")

    {:noreply,
     %{
       state
       | block_processing_task: next_task,
         queue_blocks_messages: next_queue_blocks_messages
     }}
  end

  @spec run_task(pid(), list(Block.t()), Chain.t(), pid(), backlog(), Trie.t()) :: Task.t()
  defp run_task(sup, blocks, chain, pid, backlog, trie) do
    Task.Supervisor.async(sup, fn ->
      start = Time.time_start()

      :ok =
        Logger.debug(fn ->
          "[BlockProcessor] Starting to process #{Enum.count(blocks)} block(s)."
        end)

      {processed_blocks, next_block_tree, next_backlog, next_trie} =
        StandardProcessor.process_blocks(
          blocks,
          Blocktree.new_tree(),
          backlog,
          chain,
          trie,
          false
        )

      trie_elapsed =
        Time.elapsed(fn ->
          TrieStorage.commit!(next_trie)
        end)

      :ok =
        Logger.debug(fn ->
          "[BlockProcessor] Processed #{Enum.count(processed_blocks)} block(s) in #{
            Time.elapsed(start)
          } (trie commit time: #{trie_elapsed})."
        end)

      :ok = GenServer.cast(pid, {:processed_blocks, processed_blocks, next_block_tree.best_block})

      {:ok, next_backlog, next_trie}
    end)
  end

  @spec process_completed_blocks(pid(), list(Block.t()), Chain.t()) :: :ok
  def process_completed_blocks(pid, blocks, chain) do
    GenServer.cast(pid, {:process_completed_blocks, self(), blocks, chain})
  end
end
