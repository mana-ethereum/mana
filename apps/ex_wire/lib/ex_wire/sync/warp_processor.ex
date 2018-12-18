defmodule ExWire.Sync.WarpProcessor do
  @moduledoc """
  Server responsible for processing block and state chunks in parallel for the
  Warp Queue. For more information about how the chunks are processed, see
  `PowProcessor`.

  State and data chunks from the warp are processed in parallel. After the
  accounts of state chunks are extracted, we spawn a different task which
  stores the data from those accounts into the state trie, one by one.
  """
  use GenServer

  require Logger

  alias Exth.Time
  alias ExWire.Packet.Capability.Par.SnapshotData.{BlockChunk, StateChunk}
  alias ExWire.Sync.WarpProcessor.PowProcessor
  alias MerklePatriciaTree.{Trie, TrieStorage}

  @type block_chunk_request :: {
          EVM.hash(),
          BlockChunk.t(),
          pid()
        }
  @type state_chunk_request :: {
          EVM.hash(),
          StateChunk.t(),
          pid()
        }
  @type state :: %{
          parallelism: non_neg_integer(),
          sup: pid(),
          trie: Trie.t(),
          processor_mod: module(),
          state_root: EVM.hash(),
          queued_block_chunks: list(block_chunk_request()),
          queued_state_chunks: list(state_chunk_request()),
          state_processing_task: Task.t()
        }
  @type processor_mod :: PowProcessor

  @name __MODULE__

  @doc """
  Initializes a new WarpProcessor server.

  Parallelism describes how many active tasks should run at once. That is,
  how many block or state chunks are processed in parallel.

  State root is the current state root after processing state chunks. This
  should start as the empty trie if starting a fresh warp.

  Trie should be a caching trie with the main chain as the permanent db.

  Processor mod refers to the processor...
  """
  @spec start_link({integer(), Trie.t(), EVM.hash(), processor_mod()}, Keyword.t()) ::
          GenServer.on_start()
  def start_link({parallelism, trie, state_root, processor_mod}, opts \\ []) do
    GenServer.start_link(
      __MODULE__,
      [
        parallelism: parallelism,
        trie: trie,
        state_root: state_root,
        processor_mod: processor_mod
      ],
      name: Keyword.get(opts, :name, @name)
    )
  end

  @doc """
  Initializes gen server with options from `start_link`.
  """
  @impl true
  def init(
        parallelism: parallelism,
        trie: trie,
        state_root: state_root,
        processor_mod: processor_mod
      ) do
    {:ok, sup} = Task.Supervisor.start_link()

    {:ok,
     %{
       parallelism: parallelism,
       sup: sup,
       trie: trie,
       processor_mod: processor_mod,
       state_root: state_root,
       queued_block_chunks: [],
       queued_state_chunks: [],
       state_processing_task: nil,
       queue_state_processing_tasks: []
     }}
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
  # When a task block or state chunk processing task completes, attempts to
  # de-queue another task for processing, keeping us at our limit of
  # parallelism.
  def handle_cast(
        :spawn_new_tasks,
        state = %{
          sup: sup,
          trie: trie,
          processor_mod: processor_mod,
          parallelism: parallelism,
          queued_block_chunks: queued_block_chunks,
          queued_state_chunks: queued_state_chunks
        }
      ) do
    {:done, next_queued_block_chunks, next_queued_state_chunks} =
      spawn_new_tasks(
        sup,
        trie,
        processor_mod,
        parallelism,
        queued_block_chunks,
        queued_state_chunks
      )

    {:noreply,
     %{
       state
       | queued_block_chunks: next_queued_block_chunks,
         queued_state_chunks: next_queued_state_chunks
     }}
  end

  # Called when we receive a new block chunk for a sync peer. Either begins
  # processing or enqueues the task for later processing.
  def handle_cast(
        {:new_block_chunk, chunk_hash, block_chunk, pid},
        state = %{sup: sup, trie: trie}
      ) do
    new_state = maybe_new_block_chunk_task(state, sup, chunk_hash, block_chunk, trie, pid)

    {:noreply, new_state}
  end

  # Called when we receive a new state chunk for a sync peer. Either begins
  # processing or enqueues the task for later processing.
  def handle_cast(
        {:new_state_chunk, chunk_hash, state_chunk, pid},
        state = %{sup: sup, trie: trie}
      ) do
    new_state = maybe_new_state_chunk_task(state, sup, chunk_hash, state_chunk, trie, pid)

    {:noreply, new_state}
  end

  # Called when we receive new account states that are ready to process into
  # the state trie. If we are not currently processing a task, we will begin
  # processing, otherwise we'll queue the state task until we've completed
  # the current process.
  def handle_cast(
        {:new_account_states, chunk_hash, account_states, pid},
        state = %{
          sup: sup,
          trie: trie,
          state_root: state_root,
          processor_mod: processor_mod,
          state_processing_task: nil
        }
      ) do
    task =
      new_account_states_task(
        sup,
        chunk_hash,
        account_states,
        trie,
        state_root,
        processor_mod,
        pid
      )

    {:noreply, %{state | state_processing_task: task}}
  end

  def handle_cast(
        el = {:new_account_states, _chunk_hash, _account_states, _pid},
        state = %{queue_state_processing_tasks: queue_state_processing_tasks}
      ) do
    {:noreply,
     %{
       state
       | queue_state_processing_tasks: [el | queue_state_processing_tasks]
     }}
  end

  # When a task completes, it may be a block or state chunk processing task,
  # or it may be an account state task. If it's an account state task that
  # has successfully completed, we store the new state root it generated
  # so it can be used by the next task. If it's an account state task that
  # has succesfully terminated, we try to pull a new task from the queue.
  @spec handle_task_complete(term(), term(), state()) :: state()
  defp handle_task_complete(
         ref,
         status,
         state = %{
           sup: sup,
           trie: trie,
           state_root: state_root,
           processor_mod: processor_mod,
           state_processing_task: %Task{ref: task_ref},
           queue_state_processing_tasks: queue_state_processing_tasks
         }
       )
       when ref == task_ref do
    case status do
      {:ok, {:next_state_root, next_state_root}} ->
        %{state | state_root: next_state_root}

      :down ->
        {next_task, next_queue} =
          case queue_state_processing_tasks do
            [{:new_account_states, chunk_hash, account_states, pid} | next_queue] ->
              task =
                new_account_states_task(
                  sup,
                  chunk_hash,
                  account_states,
                  trie,
                  state_root,
                  processor_mod,
                  pid
                )

              {task, next_queue}

            _ ->
              {nil, []}
          end

        %{state | state_processing_task: next_task, queue_state_processing_tasks: next_queue}
    end
  end

  # An block or state chunk task completed successfully, ignore the result
  defp handle_task_complete(_ref, {:ok, _msg}, state), do: state

  # A block or state chunk task has terminated, try to spawn a new one
  defp handle_task_complete(_ref, :down, state) do
    GenServer.cast(self(), :spawn_new_tasks)

    state
  end

  # Try and spawn more children if we have queued block or state chunks
  # and we aren't at max parallelism.
  @spec spawn_new_tasks(
          pid(),
          Trie.t(),
          processor_mod(),
          non_neg_integer(),
          list(block_chunk_request()),
          list(state_chunk_request())
        ) :: {:done, list(block_chunk_request()), list(state_chunk_request())}
  # When we have a queued up block chunk...
  defp spawn_new_tasks(
         sup,
         trie,
         processor_mod,
         parallelism,
         queued_block_chunks = [{chunk_hash, block_chunk, pid} | rest_queued_block_chunks],
         queued_state_chunks
       ) do
    # TODO: We should probably keep track of children ourselves, but for now,
    # we just query the supervisor. This actually restricts parallelism since
    # our account state processor counts here.
    if current_child_count(sup) <= parallelism do
      _task = new_block_chunk_task(sup, chunk_hash, block_chunk, trie, processor_mod, pid)

      spawn_new_tasks(
        sup,
        trie,
        processor_mod,
        parallelism,
        rest_queued_block_chunks,
        queued_state_chunks
      )
    else
      {:done, queued_block_chunks, queued_state_chunks}
    end
  end

  # When we have a queued up state chunk...
  defp spawn_new_tasks(
         sup,
         trie,
         processor_mod,
         parallelism,
         queued_block_chunks = [],
         queued_state_chunks = [
           {chunk_hash, state_chunk, pid} | rest_queued_state_chunks
         ]
       ) do
    if current_child_count(sup) <= parallelism do
      _task = new_state_chunk_task(self(), sup, chunk_hash, state_chunk, trie, processor_mod, pid)

      spawn_new_tasks(
        sup,
        trie,
        processor_mod,
        parallelism,
        queued_block_chunks,
        rest_queued_state_chunks
      )
    else
      {:done, queued_block_chunks, queued_state_chunks}
    end
  end

  # When we have no queued up chunks...
  defp spawn_new_tasks(_sup, _trie, _processor_mod, _parallelism, [], []) do
    {:done, [], []}
  end

  # If we are below max parallelism, spawn a new block chunk processing task, or queue
  # the block chunk if we've hit max parallelism.
  @spec maybe_new_block_chunk_task(state(), pid(), EVM.hash(), BlockChunk.t(), Trie.t(), pid()) ::
          state()
  def maybe_new_block_chunk_task(
        state = %{parallelism: parallelism, processor_mod: processor_mod},
        sup,
        chunk_hash,
        block_chunk,
        trie,
        pid
      ) do
    if current_child_count(sup) <= parallelism do
      _task = new_block_chunk_task(sup, chunk_hash, block_chunk, trie, processor_mod, pid)

      state
    else
      :ok =
        Logger.debug(fn ->
          "[Warp] Processor block queue size: #{Enum.count(state.queued_block_chunks) + 1}"
        end)

      %{
        state
        | queued_block_chunks: [
            {chunk_hash, block_chunk, pid} | state.queued_block_chunks
          ]
      }
    end
  end

  # The task to process a block. When we process a block, we just verify the details
  # about that block, store it's transactions, receipts and block data to the database,
  # and return the processed data back to the sync process.
  @spec new_block_chunk_task(pid(), EVM.hash(), BlockChunk.t(), Trie.t(), processor_mod(), pid()) ::
          Task.t()
  defp new_block_chunk_task(sup, chunk_hash, block_chunk, trie, processor_mod, pid) do
    task_trie = TrieStorage.with_clean_cache(trie)

    Task.Supervisor.async(sup, fn ->
      start = Time.time_start()

      :ok =
        Logger.debug(fn ->
          "[Warp] Starting to process #{Enum.count(block_chunk.block_data_list)} block(s)."
        end)

      {processed_blocks, block, next_trie} =
        processor_mod.process_block_chunk(block_chunk, task_trie)

      trie_elapsed =
        Time.elapsed(fn ->
          TrieStorage.commit!(next_trie)
        end)

      :ok =
        Logger.debug(fn ->
          "[Warp] Processed #{Enum.count(processed_blocks)} block(s) in #{Time.elapsed(start)} (trie commit time: #{
            trie_elapsed
          })."
        end)

      :ok = GenServer.cast(pid, {:processed_block_chunk, chunk_hash, processed_blocks, block})

      :ok
    end)
  end

  # If we are below max parallelism, spawn a new state chunk processing task, or queue
  # the state chunk if we've hit max parallelism.
  @spec maybe_new_state_chunk_task(state(), pid(), EVM.hash(), StateChunk.t(), Trie.t(), pid()) ::
          state()
  defp maybe_new_state_chunk_task(
         state = %{parallelism: parallelism, processor_mod: processor_mod},
         sup,
         chunk_hash,
         state_chunk,
         trie,
         pid
       ) do
    if current_child_count(sup) <= parallelism do
      _task = new_state_chunk_task(self(), sup, chunk_hash, state_chunk, trie, processor_mod, pid)

      state
    else
      :ok =
        Logger.debug(fn ->
          "[Warp] Processor state queue size: #{Enum.count(state.queued_state_chunks) + 1}"
        end)

      %{
        state
        | queued_state_chunks: [
            {chunk_hash, state_chunk, pid} | state.queued_state_chunks
          ]
      }
    end
  end

  # The task to process a state chunk. When we process a state chunk, we decode the
  # details about the included account entries. Then we pass the account state data
  # back to this process to process into the state trie.
  @spec new_state_chunk_task(
          pid(),
          pid(),
          EVM.hash(),
          StateChunk.t(),
          Trie.t(),
          processor_mod(),
          pid()
        ) :: Task.t()
  defp new_state_chunk_task(processor_pid, sup, chunk_hash, state_chunk, trie, processor_mod, pid) do
    task_trie = TrieStorage.with_clean_cache(trie)

    Task.Supervisor.async(sup, fn ->
      start = Time.time_start()

      :ok =
        Logger.debug(fn ->
          "[Warp] Starting to process #{Enum.count(state_chunk.account_entries)} account(s)."
        end)

      {account_states, next_trie} = processor_mod.process_state_chunk(state_chunk, task_trie)

      trie_elapsed =
        Time.elapsed(fn ->
          TrieStorage.commit!(next_trie)
        end)

      :ok =
        Logger.debug(fn ->
          "[Warp] Processed #{Enum.count(state_chunk.account_entries)} account(s) #{
            Time.elapsed(start)
          } (trie commit time: #{trie_elapsed})."
        end)

      GenServer.cast(processor_pid, {:new_account_states, chunk_hash, account_states, pid})

      :ok
    end)
  end

  # The task to process new account states. We iterate over the account states
  # and store each account into a state root trie. We will later verify that
  # state root matches the one that was given in the warp manifest.
  @spec new_account_states_task(
          pid(),
          EVM.hash(),
          list(PowProcessor.account_state()),
          Trie.t(),
          EVM.hash(),
          processor_mod(),
          pid()
        ) :: Task.t()
  defp new_account_states_task(
         sup,
         chunk_hash,
         account_states,
         trie,
         state_root,
         processor_mod,
         pid
       ) do
    task_trie = TrieStorage.with_clean_cache(trie)

    Task.Supervisor.async(sup, fn ->
      start = Time.time_start()

      processed_accounts = Enum.count(account_states)

      :ok =
        Logger.debug(fn ->
          "[Warp] Starting to process #{processed_accounts} account state(s) from state root #{
            Exth.encode_hex(state_root)
          }."
        end)

      state_trie = TrieStorage.set_root_hash(task_trie, state_root)
      next_state_trie = processor_mod.process_account_states(account_states, state_trie)
      next_state_root = TrieStorage.root_hash(next_state_trie)

      trie_elapsed =
        Time.elapsed(fn ->
          TrieStorage.commit!(next_state_trie)
        end)

      :ok =
        Logger.debug(fn ->
          "[Warp] Processed #{processed_accounts} account state(s) #{Time.elapsed(start)} (trie commit time: #{
            trie_elapsed
          }). New state root: #{Exth.encode_hex(next_state_root)}"
        end)

      :ok =
        Logger.debug(fn ->
          "[Warp] #{processed_accounts}: #{Exth.encode_hex(state_root)}->#{
            Exth.encode_hex(next_state_root)
          }"
        end)

      :ok =
        GenServer.cast(
          pid,
          {:processed_state_chunk, chunk_hash, processed_accounts, next_state_root}
        )

      {:next_state_root, next_state_root}
    end)
  end

  @doc """
  Called when we receive a new block chunk from a peer to ask warp processor
  to process the block chunk asynchronously.

  Block chunks contain data about the last few thousand blocks, such as a list
  of transactions and receipts.
  """
  @spec new_block_chunk(pid(), EVM.hash(), BlockChunk.t()) :: :ok
  def new_block_chunk(pid, chunk_hash, block_chunk) do
    GenServer.cast(pid, {:new_block_chunk, chunk_hash, block_chunk, self()})
  end

  @doc """
  Called when we receive a new state chunk from a peer to ask warp processor
  to process the block chunk asynchronously.

  State chunks contain the account data necessary to build the state of the
  most recent block in the warp from a blank database.
  """
  @spec new_state_chunk(pid(), EVM.hash(), StateChunk.t()) :: :ok
  def new_state_chunk(pid, chunk_hash, state_chunk) do
    GenServer.cast(pid, {:new_state_chunk, chunk_hash, state_chunk, self()})
  end

  # The child count is the total number of asynchronous tasks being run by
  # this processor. This should be at most parallelism plus one (since we
  # also have the account state processor, as well as the state and block
  # chunk processors).
  @spec current_child_count(pid()) :: non_neg_integer()
  defp current_child_count(sup) do
    sup
    |> Task.Supervisor.children()
    |> Enum.count()
  end
end
