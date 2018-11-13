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
  alias Blockchain.Block
  alias ExWire.Config
  alias ExWire.Packet.{BlockBodies, BlockHeaders, GetBlockBodies, GetBlockHeaders}
  alias ExWire.PeerSupervisor
  alias ExWire.Struct.{BlockQueue, Peer}
  alias Blockchain.{Blocktree, Chain}
  alias Blockchain.Blocktree.State
  alias MerklePatriciaTree.{CachingTrie, DB.RocksDB, Trie, TrieStorage}

  @save_block_interval 100
  @blocks_per_request 100
  @startup_delay 2_000
  @retry_delay 5_000

  @type state :: %{
          chain: Chain.t(),
          block_queue: BlockQueue.t(),
          block_tree: Blocktree.t(),
          trie: Trie.t(),
          last_requested_block: integer() | nil
        }

  @doc """
  Starts a sync process for a given chain.
  """
  @spec start_link(Chain.t()) :: GenServer.on_start()
  def start_link(chain) do
    GenServer.start_link(__MODULE__, chain, name: __MODULE__)
  end

  @doc """
  Once we start a sync server, we'll wait for active peers and
  then begin asking for blocks.

  TODO: Let's say we haven't connected to any peers before we call
        `request_next_block`, then the client effectively stops syncing.
        We should handle this case more gracefully.
  """
  @impl true
  def init(chain) do
    {block_tree, trie} = load_sync_state(chain)
    block_queue = %BlockQueue{}

    Process.send_after(self(), {:request_next_block, block_queue, block_tree}, @startup_delay)

    {:ok,
     %{
       chain: chain,
       block_queue: block_queue,
       block_tree: block_tree,
       trie: trie,
       last_requested_block: nil
     }}
  end

  @doc """
  When were receive a block header, we'll add it to our block queue. When we
  receive the corresponding block body, we'll add that as well.
  """
  @impl true
  def handle_info({:request_next_block, block_queue, block_tree}, state) do
    new_state = handle_request_next_block(block_queue, block_tree, state)

    {:noreply, new_state}
  end

  def handle_info({:packet, %BlockHeaders{} = block_headers, peer}, state) do
    {:noreply, handle_block_headers(block_headers, peer, state)}
  end

  def handle_info({:packet, %BlockBodies{} = block_bodies, _peer}, state) do
    {:noreply, handle_block_bodies(block_bodies, state)}
  end

  def handle_info({:packet, packet, peer}, state) do
    :ok = Logger.info(fn -> "[Sync] Ignoring packet #{packet.__struct__} from #{peer}" end)

    {:noreply, state}
  end

  @doc """
  Dispatches a packet of `GetBlockHeaders` to all peers for the next block
  number that we don't have in our block queue or state tree.
  """
  @spec handle_request_next_block(BlockQueue.t(), Blocktree.t(), state()) :: state()
  def handle_request_next_block(block_queue, block_tree, state) do
    next_block_to_request = request_next_block(block_queue, block_tree)

    if PeerSupervisor.connected_peer_count() > 0 do
      :ok = Logger.debug(fn -> "[Sync] Requesting block #{next_block_to_request}" end)

      :ok =
        PeerSupervisor.send_packet(%GetBlockHeaders{
          block_identifier: next_block_to_request,
          max_headers: @blocks_per_request,
          skip: 0,
          reverse: false
        })

      Map.put(state, :last_requested_block, next_block_to_request + @blocks_per_request)
    else
      :ok =
        Logger.debug(fn ->
          "[Sync] No connected peers to sync, trying again in #{@retry_delay / 1000} second(s)"
        end)

      Process.send_after(self(), {:request_next_block, block_queue, block_tree}, @retry_delay)

      state
    end
  end

  @doc """
  When we get block headers from peers, we add them to our current block
  queue to incorporate the blocks into our state chain.

  Note: some blocks (esp. older ones or on test nets) may be empty, and thus
        we won't need to request the bodies. These we process right away.
        Otherwise, we request the block bodies for the blocks we don't
        know about.

  Note: we process blocks in memroy and save our state tree every so often.
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
          last_requested_block: last_requested_block
        }
      ) do
    {next_block_queue, next_block_tree, next_trie, header_hashes} =
      Enum.reduce(block_headers.headers, {block_queue, block_tree, trie, []}, fn header,
                                                                                 {block_queue,
                                                                                  block_tree,
                                                                                  trie,
                                                                                  header_hashes} ->
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

        {next_block_queue, next_block_tree, next_trie, next_header_hashes}
      end)

    :ok =
      PeerSupervisor.send_packet(%GetBlockBodies{
        hashes: header_hashes
      })

    {new_last_requested_block, next_trie} =
      maybe_request_new_block_or_save(
        block_tree,
        next_block_tree,
        next_trie,
        next_block_queue,
        last_requested_block
      )

    state
    |> Map.put(:block_queue, next_block_queue)
    |> Map.put(:block_tree, next_block_tree)
    |> Map.put(:trie, next_trie)
    |> Map.put(:last_requested_block, new_last_requested_block)
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
          trie: trie,
          last_requested_block: last_requested_block
        }
      ) do
    {next_block_queue, next_block_tree, next_trie} =
      Enum.reduce(block_bodies.blocks, {block_queue, block_tree, trie}, fn block_body,
                                                                           {block_queue,
                                                                            block_tree, trie} ->
        BlockQueue.add_block_struct(block_queue, block_tree, block_body, chain, trie)
      end)

    {new_last_requested_block, next_trie} =
      maybe_request_new_block_or_save(
        block_tree,
        next_block_tree,
        next_trie,
        next_block_queue,
        last_requested_block
      )

    state
    |> Map.put(:block_queue, next_block_queue)
    |> Map.put(:block_tree, next_block_tree)
    |> Map.put(:trie, next_trie)
    |> Map.put(:last_requested_block, new_last_requested_block)
  end

  @doc """
  Determines the next block we don't yet have in our blocktree and
  dispatches a request to all connected peers for that block and the
  next `n` blocks after it.
  """
  @spec request_next_block(BlockQueue.t(), Blocktree.t()) :: integer()
  def request_next_block(block_queue, block_tree) do
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

  @spec maybe_request_new_block_or_save(
          Blocktree.t(),
          Blocktree.t(),
          Trie.t(),
          BlockQueue.t(),
          integer()
        ) :: {integer(), Trie.t()}
  defp maybe_request_new_block_or_save(
         block_tree,
         next_block_tree,
         trie,
         block_queue,
         last_requested_block
       ) do
    # We can make this better, but it's basically "if we change, request another block"
    if block_tree != next_block_tree do
      maybe_commited_trie = maybe_save_sync_state(next_block_tree, trie)

      {request_next_block(block_queue, next_block_tree), maybe_commited_trie}
    else
      {last_requested_block, trie}
    end
  end

  # Loads sync state from our backing database
  @spec load_sync_state(Chain.t()) :: {Blocktree.t(), CachingTrie.t()}
  defp load_sync_state(chain) do
    db = RocksDB.init(Config.db_name(chain))

    trie =
      db
      |> Trie.new()
      |> CachingTrie.new()

    blocktree = State.load_tree(db)

    {blocktree, trie}
  end

  # Save sync state from our backing database if the most recently
  # added block is a multiple of our block save interval.
  @spec maybe_save_sync_state(Blocktree.t(), Trie.t()) :: Trie.t()
  defp maybe_save_sync_state(blocktree, trie) do
    block_number = blocktree.best_block.header.number

    if rem(block_number, @save_block_interval) == 0 do
      committed_trie = TrieStorage.commit!(trie)

      committed_trie
      |> TrieStorage.permanent_db()
      |> State.save_tree(blocktree)

      committed_trie
    else
      trie
    end
  end
end
