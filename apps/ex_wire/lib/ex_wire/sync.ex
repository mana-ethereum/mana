defmodule ExWire.Sync do
  @moduledoc """
  This is the heart of our syncing logic. Once we've connected to a number
  of peers via `ExWire.PeerSupervisor`, we begin to ask for new blocks from
  those peers. As we receive blocks, we add them to our
  `ExWire.Struct.BlockQueue`.

  If the blocks are confirmed by enough peers, then we verify the block and
  add it to our block tree.

  Note: we do not currently store the block tree, and thus we need to build
        it from genesis each time.
  """
  use GenServer

  require Logger

  alias Block.Header
  alias Blockchain.{Block, Blocktree, Blocktree.State, Chain}
  alias Exth.Time
  alias ExWire.Packet
  alias ExWire.PeerSupervisor
  alias ExWire.Struct.{BlockQueue, Peer, WarpQueue}
  alias ExWire.Sync.{WarpProcessor, WarpState}
  alias MerklePatriciaTree.{DB, Trie, TrieStorage}

  alias ExWire.Packet.Capability.Eth.{
    BlockBodies,
    BlockHeaders,
    GetBlockBodies,
    GetBlockHeaders
  }

  alias ExWire.Packet.Capability.Par.{
    GetSnapshotData,
    GetSnapshotManifest,
    SnapshotData,
    SnapshotManifest
  }

  alias ExWire.Packet.Capability.Par.SnapshotData.{BlockChunk, StateChunk}

  @save_block_interval 100
  @blocks_per_request 100
  @startup_delay 10_000
  @retry_delay 5_000
  @request_limit 5
  @queue_limit 5

  @type state :: %{
          chain: Chain.t(),
          block_queue: BlockQueue.t(),
          warp_queue: WarpQueue.t(),
          block_tree: Blocktree.t(),
          trie: Trie.t(),
          last_requested_block: integer() | nil,
          starting_block_number: non_neg_integer() | nil,
          highest_block_number: non_neg_integer() | nil,
          warp: boolean(),
          warp_processor: GenServer.server()
        }

  @spec get_state(GenServer.server()) :: state
  def get_state(name \\ __MODULE__) do
    GenServer.call(name, :get_state)
  end

  @doc """
  Starts a sync process for a given chain.
  """
  @spec start_link({Trie.t(), Chain.t(), boolean(), WarpQueue.t() | nil}, Keyword.t()) ::
          GenServer.on_start()
  def start_link({trie, chain, warp, warp_queue}, opts \\ []) do
    warp_processor = Keyword.get(opts, :warp_processor, WarpProcessor)

    GenServer.start_link(__MODULE__, {trie, chain, warp, warp_queue, warp_processor},
      name: Keyword.get(opts, :name, __MODULE__)
    )
  end

  @doc """
  Once we start a sync server, we'll wait for active peers and
  then begin asking for blocks.

  TODO: Let's say we haven't connected to any peers before we call
        `request_next_block`, then the client effectively stops syncing.
        We should handle this case more gracefully.
  """
  @impl true
  def init({trie, chain, warp, warp_queue, warp_processor}) do
    block_tree = load_sync_state(TrieStorage.permanent_db(trie))
    block_queue = %BlockQueue{}

    {:ok, {block, _caching_trie}} = Blocktree.get_best_block(block_tree, chain, trie)

    state = %{
      chain: chain,
      block_queue: block_queue,
      warp_queue: warp_queue,
      block_tree: block_tree,
      trie: trie,
      last_requested_block: nil,
      starting_block_number: block.header.number,
      highest_block_number: block.header.number,
      warp: warp,
      warp_processor: warp_processor
    }

    if warp do
      if warp_queue.manifest do
        Process.send_after(self(), :resume_warp, @startup_delay)
      else
        Process.send_after(self(), :request_manifest, @startup_delay)
      end
    else
      request_next_block(@startup_delay)
    end

    {:ok, state}
  end

  defp request_next_block(timeout \\ 0) do
    Process.send_after(self(), :request_next_block, timeout)
  end

  @impl true
  def handle_cast(
        {:processed_block_chunk, chunk_hash, processed_blocks, block},
        state = %{warp_queue: warp_queue}
      ) do
    next_state =
      warp_queue
      |> WarpQueue.processed_block_chunk(chunk_hash, block, processed_blocks)
      |> dispatch_new_warp_queue_requests()
      |> save_and_check_warp_complete(state)

    {:noreply, next_state}
  end

  def handle_cast(
        {:processed_state_chunk, chunk_hash, processed_accounts, state_root},
        state = %{warp_queue: warp_queue}
      ) do
    next_state =
      warp_queue
      |> WarpQueue.processed_state_chunk(chunk_hash, processed_accounts, state_root)
      |> dispatch_new_warp_queue_requests()
      |> save_and_check_warp_complete(state)

    {:noreply, next_state}
  end

  @doc """
  When were receive a block header, we'll add it to our block queue. When we
  receive the corresponding block body, we'll add that as well.
  """
  @impl true
  def handle_info(
        :request_next_block,
        state = %{block_queue: block_queue, block_tree: block_tree}
      ) do
    new_state = handle_request_next_block(block_queue, block_tree, state)

    {:noreply, new_state}
  end

  def handle_info(:resume_warp, state = %{warp_queue: warp_queue}) do
    new_state =
      warp_queue
      |> dispatch_new_warp_queue_requests()
      |> save_and_check_warp_complete(state, false)

    {:noreply, new_state}
  end

  def handle_info(:request_manifest, state) do
    new_state = handle_request_manifest(state)

    {:noreply, new_state}
  end

  def handle_info({:request_chunk, chunk_hash}, state) do
    new_state = handle_request_chunk(chunk_hash, state)

    {:noreply, new_state}
  end

  def handle_info({:packet, %BlockHeaders{} = block_headers, peer}, state) do
    {:noreply, handle_block_headers(block_headers, peer, state)}
  end

  def handle_info({:packet, %BlockBodies{} = block_bodies, _peer}, state) do
    {:noreply, handle_block_bodies(block_bodies, state)}
  end

  def handle_info({:packet, %SnapshotManifest{} = snapshot_manifest, peer}, state) do
    {:noreply, handle_snapshot_manifest(snapshot_manifest, peer, state)}
  end

  def handle_info(
        {:packet, %SnapshotData{} = snapshot_data, peer},
        state
      ) do
    {:noreply, handle_snapshot_data(snapshot_data, peer, state)}
  end

  def handle_info({:packet, packet, peer}, state) do
    :ok = Exth.trace(fn -> "[Sync] Ignoring packet #{packet.__struct__} from #{peer}" end)

    {:noreply, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @doc """
  Dispatches a packet of `GetSnapshotManifest` to all capable peers.

  # TODO: That "capable peers" part.
  """
  @spec handle_request_manifest(state()) :: state()
  def handle_request_manifest(state) do
    if send_with_retry(%GetSnapshotManifest{}, :all, :request_manifest) do
      :ok = Logger.debug(fn -> "[Sync] Requested snapshot manifests" end)
    end

    state
  end

  @doc """
  Dispatches a packet of `GetSnapshotData` to a random capable peer.

  # TODO: That "capable peer" part.
  """
  @spec handle_request_chunk(EVM.hash(), state()) :: state()
  def handle_request_chunk(chunk_hash, state) do
    if send_with_retry(
         %GetSnapshotData{chunk_hash: chunk_hash},
         :random,
         {:request_chunk, chunk_hash}
       ) do
      :ok = Logger.debug(fn -> "Requested block chunk #{Exth.encode_hex(chunk_hash)}..." end)
    end

    state
  end

  @doc """
  Dispatches a packet of `GetBlockHeaders` to a peer for the next block
  number that we don't have in our block queue or state tree.
  """
  @spec handle_request_next_block(BlockQueue.t(), Blocktree.t(), state()) :: state()
  def handle_request_next_block(block_queue, block_tree, state) do
    next_block_to_request = get_next_block_to_request(block_queue, block_tree)

    if send_with_retry(
         %GetBlockHeaders{
           block_identifier: next_block_to_request,
           max_headers: @blocks_per_request,
           skip: 0,
           reverse: false
         },
         :random,
         :request_next_block
       ) do
      :ok = Logger.debug(fn -> "[Sync] Requested block #{next_block_to_request}" end)

      Map.put(state, :last_requested_block, next_block_to_request + @blocks_per_request)
    else
      state
    end
  end

  @doc """
  When we receive a new snapshot manifest, we add it to our warp queue. We may
  have new blocks to fetch, so we ask the warp queue for more blocks to
  request. We may already, however, be waiting on blocks, in which case we
  do nothing.
  """
  @spec handle_snapshot_manifest(SnapshotManifest.t(), Peer.t(), state()) :: state()
  def handle_snapshot_manifest(%SnapshotManifest{manifest: nil}, _peer, state) do
    :ok = Logger.info("Received empty Snapshot Manifest")

    state
  end

  def handle_snapshot_manifest(
        %SnapshotManifest{manifest: manifest},
        _peer,
        state = %{warp_queue: warp_queue}
      ) do
    next_state =
      warp_queue
      |> WarpQueue.new_manifest(manifest)
      |> dispatch_new_warp_queue_requests()
      |> save_and_check_warp_complete(state)

    next_state
  end

  @spec dispatch_new_warp_queue_requests(WarpQueue.t(), integer(), integer()) :: WarpQueue.t()
  defp dispatch_new_warp_queue_requests(
         warp_queue,
         request_limit \\ @request_limit,
         queue_limit \\ @queue_limit
       ) do
    {new_warp_queue, hashes_to_request} =
      WarpQueue.get_hashes_to_request(warp_queue, request_limit, queue_limit)

    for hash <- hashes_to_request do
      request_chunk(hash)
    end

    new_warp_queue
  end

  @doc """
  When we receive a SnapshotData, let's try to add the received block to the
  warp queue. We may decide to request new blocks at this time.
  """
  @spec handle_snapshot_data(SnapshotData.t(), Peer.t(), state()) :: state()
  def handle_snapshot_data(%SnapshotData{chunk: nil}, _peer, state) do
    :ok = Logger.debug("Received empty SnapshotData message.")

    state
  end

  def handle_snapshot_data(
        %SnapshotData{hash: block_chunk_hash, chunk: block_chunk = %BlockChunk{}},
        _peer,
        state = %{warp_queue: warp_queue, warp_processor: warp_processor}
      ) do
    next_warp_queue =
      warp_queue
      |> WarpQueue.new_block_chunk(block_chunk_hash)
      |> dispatch_new_warp_queue_requests()

    WarpProcessor.new_block_chunk(warp_processor, block_chunk_hash, block_chunk)

    %{state | warp_queue: next_warp_queue}
  end

  def handle_snapshot_data(
        %SnapshotData{hash: state_chunk_hash, chunk: state_chunk = %StateChunk{}},
        _peer,
        state = %{warp_queue: warp_queue, warp_processor: warp_processor}
      ) do
    next_warp_queue =
      warp_queue
      |> WarpQueue.new_state_chunk(state_chunk_hash)
      |> dispatch_new_warp_queue_requests()

    WarpProcessor.new_state_chunk(warp_processor, state_chunk_hash, state_chunk)

    %{state | warp_queue: next_warp_queue}
  end

  @doc """
  When we get block headers from peers, we add them to our current block
  queue to incorporate the blocks into our state chain.

  Note: some blocks (esp. older ones or on test nets) may be empty, and thus
        we won't need to request the bodies. These we process right away.
        Otherwise, we request the block bodies for the blocks we don't
        know about.

  Note: we process blocks in memory and save our state tree every so often.
  Note: this mimics a lot of the logic from block bodies since a header
        of an empty block *is* a complete block.
  """
  @spec handle_block_headers(BlockHeaders.t(), Peer.t(), state()) :: state()
  def handle_block_headers(
        block_headers,
        peer,
        state = %{
          block_queue: block_queue,
          block_tree: block_tree,
          chain: chain,
          trie: trie,
          highest_block_number: highest_block_number
        }
      ) do
    {next_highest_block_number, next_block_queue, next_block_tree, next_trie, header_hashes} =
      Enum.reduce(
        block_headers.headers,
        {highest_block_number, block_queue, block_tree, trie, []},
        fn header, {highest_block_number, block_queue, block_tree, trie, header_hashes} ->
          header_hash = header |> Header.hash()

          {next_block_queue, next_block_tree, next_trie, should_request_block} =
            BlockQueue.add_header(
              block_queue,
              block_tree,
              header,
              header_hash,
              peer.remote_id,
              chain,
              trie
            )

          next_header_hashes =
            if should_request_block do
              :ok = Logger.debug(fn -> "[Sync] Requesting block body #{header.number}" end)

              [header_hash | header_hashes]
            else
              header_hashes
            end

          next_highest_block_number = Kernel.max(highest_block_number, header.number)

          {next_highest_block_number, next_block_queue, next_block_tree, next_trie,
           next_header_hashes}
        end
      )

    :ok =
      PeerSupervisor.send_packet(
        %GetBlockBodies{
          hashes: header_hashes
        },
        :random
      )

    next_maybe_saved_trie = maybe_save(block_tree, next_block_tree, next_trie)
    :ok = maybe_request_next_block(next_block_queue)

    state
    |> Map.put(:block_queue, next_block_queue)
    |> Map.put(:block_tree, next_block_tree)
    |> Map.put(:trie, next_maybe_saved_trie)
    |> Map.put(:highest_block_number, next_highest_block_number)
  end

  @doc """
  After we're given headers from peers, we request the block bodies. Here we
  try to add those blocks to our block tree. It's possbile we receive block
  `n + 1` before we receive block `n`, so in these cases, we queue up the
  blocks until we process the parent block.

  Note: we process blocks in memory and save our state tree every so often.
  """
  @spec handle_block_bodies(BlockBodies.t(), state()) :: state()
  def handle_block_bodies(
        block_bodies,
        state = %{
          block_queue: block_queue,
          block_tree: block_tree,
          chain: chain,
          trie: trie
        }
      ) do
    {next_block_queue, next_block_tree, next_trie} =
      Enum.reduce(block_bodies.blocks, {block_queue, block_tree, trie}, fn block_body,
                                                                           {block_queue,
                                                                            block_tree, trie} ->
        BlockQueue.add_block_struct(block_queue, block_tree, block_body, chain, trie)
      end)

    next_maybe_saved_trie = maybe_save(block_tree, next_block_tree, next_trie)
    :ok = maybe_request_next_block(next_block_queue)

    state
    |> Map.put(:block_queue, next_block_queue)
    |> Map.put(:block_tree, next_block_tree)
    |> Map.put(:trie, next_maybe_saved_trie)
  end

  # Determines the next block we don't yet have in our blocktree and
  # dispatches a request to all connected peers for that block and the
  # next `n` blocks after it.
  @spec get_next_block_to_request(BlockQueue.t(), Blocktree.t()) :: integer()
  defp get_next_block_to_request(block_queue, block_tree) do
    # This is the best we know about
    next_number =
      case block_tree.best_block do
        nil -> 0
        %Block{header: %Header{number: number}} -> number + 1
      end

    # But we may have it queued up already in the block queue, let's
    # start from the first we *don't* know about. It's possible there's
    # holes in block queue, so it's not `max(best_block.number, max(keys(queue)))`,
    # though it could be...
    next_number
    |> Stream.iterate(fn n -> n + 1 end)
    |> Stream.reject(fn n -> MapSet.member?(block_queue.block_numbers, n) end)
    |> Enum.at(0)
  end

  @spec maybe_save(Blocktree.t(), Blocktree.t(), Trie.t()) :: Trie.t()
  defp maybe_save(block_tree, next_block_tree, trie) do
    if block_tree != next_block_tree do
      block_number = next_block_tree.best_block.header.number

      if rem(block_number, @save_block_interval) == 0 do
        save_sync_state(next_block_tree, trie)
      else
        trie
      end
    else
      trie
    end
  end

  @spec request_chunk(EVM.hash()) :: reference()
  defp request_chunk(chunk_hash) do
    Process.send_after(self(), {:request_chunk, chunk_hash}, 0)
  end

  @spec maybe_request_next_block(BlockQueue.t()) :: :ok
  defp maybe_request_next_block(block_queue) do
    # Let's pull a new block if we have none left
    _ =
      if block_queue.queue == %{} do
        request_next_block()
      end

    :ok
  end

  @spec save_and_check_warp_complete(WarpQueue.t(), state(), boolean()) :: state()
  defp save_and_check_warp_complete(warp_queue, state = %{trie: trie}, save \\ true) do
    if save do
      :ok = WarpState.save_warp_queue(TrieStorage.permanent_db(trie), warp_queue)
    end

    case WarpQueue.status(warp_queue) do
      {:pending, reason} ->
        Exth.trace(fn ->
          "[Sync] Warp incomplete due to #{to_string(reason)}"
        end)

        %{
          state
          | warp_queue: warp_queue
        }

      :success ->
        :ok =
          Logger.info("[Warp] Warp Completed in #{Time.elapsed(warp_queue.warp_start, :second)}")

        # Save our process
        saved_tried = save_sync_state(warp_queue.block_tree, trie)

        # Request a normal sync to start
        request_next_block()

        # TODO: Clear the warp cache

        # And onward!
        %{
          state
          | warp_queue: warp_queue,
            trie: saved_tried,
            warp: false
        }
    end
  end

  # Loads sync state from our backing database
  @spec load_sync_state(DB.db()) :: Blocktree.t()
  defp load_sync_state(db) do
    State.load_tree(db)
  end

  # Save sync state from our backing database.
  @spec save_sync_state(Blocktree.t(), Trie.t()) :: Trie.t()
  defp save_sync_state(blocktree, trie) do
    committed_trie = TrieStorage.commit!(trie)

    committed_trie
    |> TrieStorage.permanent_db()
    |> State.save_tree(blocktree)

    committed_trie
  end

  @spec send_with_retry(
          Packet.packet(),
          PeerSupervisor.node_selector(),
          :request_manifest | :request_next_block | {:request_chunk, EVM.hash()}
        ) :: boolean()
  defp send_with_retry(packet, node_selector, retry_message) do
    send_packet_result =
      PeerSupervisor.send_packet(
        packet,
        node_selector
      )

    case send_packet_result do
      :ok ->
        true

      :unsent ->
        :ok =
          Logger.debug(fn ->
            "[Sync] No connected peers to send #{packet.__struct__}, trying again in #{
              @retry_delay / 1000
            } second(s)"
          end)

        Process.send_after(self(), retry_message, @retry_delay)

        false
    end
  end
end
