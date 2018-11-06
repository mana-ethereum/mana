defmodule ExWire.Sync do
  @moduledoc """
  This is the heart of our syncing logic. Once we've connected to a number
  of peers via `ExWire.PeerSupervisor`, we begin to ask for new blocks from those
  peers. As we receive blocks, we add them to our `ExWire.Struct.BlockQueue`.
  If the blocks are confirmed by enough peers, then we verify the block and
  add it to our block tree.

  Note: we do not currently store the block tree, and thus we need to build
        it from genesis each time.
  """
  use GenServer

  require Logger

  alias Block.Header
  alias Blockchain.Block
  alias ExWire.Packet.{BlockBodies, BlockHeaders, GetBlockBodies, GetBlockHeaders}
  alias ExWire.PeerSupervisor
  alias ExWire.Struct.BlockQueue
  alias Blockchain.{Blocktree, Chain, State}
  alias MerklePatriciaTree.{CachingTrie, DB.RocksDB, Trie, TrieStorage}

  @save_block_interval 100
  @blocks_per_request 100

  @doc """
  Starts a Sync process.
  """
  def start_link(db) do
    GenServer.start_link(__MODULE__, db, name: __MODULE__)
  end

  @doc """
  Once we start a sync server, we'll wait for active peers.

  TODO: We do not always want to sync from the genesis.
        We will need to add some "restore state" logic.

  # TODO: Load blocktree from state store
  """
  def init(chain) do
    {block_tree, trie} = load_sync_state(chain)
    block_queue = %BlockQueue{}

    Process.send_after(self(), {:request_next_block, block_queue, block_tree}, 1_000)

    {:ok,
     %{
       chain: chain,
       block_queue: block_queue,
       block_tree: block_tree,
       trie: trie,
       last_requested_block: nil
     }}
  end

  def handle_info({:request_next_block, block_queue, block_tree}, state) do
    next_requested_block = request_next_block(block_queue, block_tree)

    {:noreply,
     state
     |> Map.put(:last_requested_block, next_requested_block)}
  end

  @doc """
  When were receive a block header, we'll add it to our block queue. When we
  receive the corresponding block body, we'll add that as well.
  """
  def handle_info(
        {:packet, %BlockHeaders{} = block_headers, peer},
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

    PeerSupervisor.send_packet(%GetBlockBodies{
      hashes: header_hashes
    })

    # We can make this better, but it's basically "if we change, request another block"
    {new_last_requested_block, next_trie} =
      if next_block_tree != block_tree do
        maybe_commited_trie = maybe_save_sync_state(next_block_tree, next_trie)

        {request_next_block(next_block_queue, next_block_tree), maybe_commited_trie}
      else
        {last_requested_block, next_trie}
      end

    {:noreply,
     state
     |> Map.put(:block_queue, next_block_queue)
     |> Map.put(:block_tree, next_block_tree)
     |> Map.put(:trie, next_trie)
     |> Map.put(:last_requested_block, new_last_requested_block)}
  end

  def handle_info(
        {:packet, %BlockBodies{} = block_bodies, _peer},
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

    # We can make this better, but it's basically "if we change, request another block"
    {new_last_requested_block, next_trie} =
      if next_block_tree != block_tree do
        maybe_commited_trie = maybe_save_sync_state(next_block_tree, next_trie)

        {request_next_block(next_block_queue, next_block_tree), maybe_commited_trie}
      else
        {last_requested_block, next_trie}
      end

    {:noreply,
     state
     |> Map.put(:block_queue, next_block_queue)
     |> Map.put(:block_tree, next_block_tree)
     |> Map.put(:trie, next_trie)
     |> Map.put(:last_requested_block, new_last_requested_block)}
  end

  def handle_info({:packet, packet, peer}, state) do
    :ok = Logger.debug(fn -> "[Sync] Ignoring packet #{packet.__struct__} from #{peer}" end)

    {:noreply, state}
  end

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
    first_block_to_request =
      next_number
      |> Stream.iterate(fn n -> n + 1 end)
      |> Stream.reject(fn n -> MapSet.member?(block_queue.block_numbers, n) end)
      |> Enum.at(0)

    :ok = Logger.debug(fn -> "[Sync] Requesting block #{first_block_to_request}" end)

    PeerSupervisor.send_packet(%GetBlockHeaders{
      block_identifier: first_block_to_request,
      max_headers: @blocks_per_request,
      skip: 0,
      reverse: false
    })

    next_number
  end

  @spec load_sync_state(atom()) :: {Blocktree.t(), Trie.t()}
  defp load_sync_state(chain) do
    db = RocksDB.init(db_name(chain))

    trie =
      db
      |> Trie.new()
      |> CachingTrie.new()

    blocktree = State.load_tree(db)

    {blocktree, trie}
  end

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

  @spec db_name(Chain.t()) :: nonempty_charlist()
  def db_name(chain) do
    'db/mana-' ++ String.to_charlist(chain.name)
  end
end
