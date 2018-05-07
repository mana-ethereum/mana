defmodule ExWire.Sync do
  @moduledoc """
  This is the heart of our syncing logic. Once we've connected to a number
  of peers via `ExWire.PeerSup`, we begin to ask for new blocks from those
  peers. As we receive blocks, we add them to our `ExWire.Struct.BlockQueue`.
  If the blocks are confirmed by enough peers, then we verify the block and
  add it to our block tree.

  Note: we do not currently store the block tree, and thus we need to build
        it from genesis each time.
  """
  use GenServer

  require Logger

  alias Block.Header
  alias ExWire.Struct.BlockQueue
  alias ExWire.Packet.BlockHeaders
  alias ExWire.Packet.BlockBodies
  alias ExWire.PeerSupervisor

  @doc """
  Starts a Sync process.
  """
  def start_link(db) do
    GenServer.start_link(__MODULE__, db, name: ExWire.Sync)
  end

  @doc """
  Once we start a sync server, we'll wait for active peers.

  TODO: We do not always want to sync from the genesis.
        We will need to add some "restore state" logic.
  """
  def init(db) do
    block_tree = Blockchain.Blocktree.new_tree()

    {:ok,
     %{
       block_queue: %BlockQueue{},
       block_tree: block_tree,
       chain: ExWire.Config.chain(),
       db: db,
       last_requested_block: request_next_block(block_tree)
     }}
  end

  @doc """
  When were receive a block header, we'll add it to our block queue. When we receive the corresponding block body,
  we'll add that as well.
  """
  def handle_info(
        {:packet, %BlockHeaders{} = block_headers, peer},
        state = %{
          block_queue: block_queue,
          block_tree: block_tree,
          chain: chain,
          db: db,
          last_requested_block: last_requested_block
        }
      ) do
    {next_block_queue, next_block_tree} =
      Enum.reduce(block_headers.headers, {block_queue, block_tree}, fn header,
                                                                       {block_queue, block_tree} ->
        header_hash = header |> Header.hash()

        {block_queue, block_tree, should_request_block} =
          BlockQueue.add_header_to_block_queue(
            block_queue,
            block_tree,
            header,
            header_hash,
            peer.remote_id,
            chain,
            db
          )

        if should_request_block do
          Logger.debug("[Sync] Requesting block body #{header.number}")

          # TODO: Bulk up these requests?
          PeerSupervisor.send_packet(PeerSupervisor, %ExWire.Packet.GetBlockBodies{
            hashes: [header_hash]
          })
        end

        {block_queue, block_tree}
      end)

    # We can make this better, but it's basically "if we change, request another block"
    new_last_requested_block =
      if next_block_tree.parent_map != block_tree.parent_map do
        request_next_block(next_block_tree)
      else
        last_requested_block
      end

    {:noreply,
     state
     |> Map.put(:block_queue, next_block_queue)
     |> Map.put(:block_tree, next_block_tree)
     |> Map.put(:last_requested_block, new_last_requested_block)}
  end

  def handle_info(
        {:packet, %BlockBodies{} = block_bodies, _peer},
        state = %{
          block_queue: block_queue,
          block_tree: block_tree,
          chain: chain,
          db: db,
          last_requested_block: last_requested_block
        }
      ) do
    {next_block_queue, next_block_tree} =
      Enum.reduce(block_bodies.blocks, {block_queue, block_tree}, fn block_body,
                                                                     {block_queue, block_tree} ->
        BlockQueue.add_block_struct_to_block_queue(block_queue, block_tree, block_body, chain, db)
      end)

    # We can make this better, but it's basically "if we change, request another block"
    new_last_requested_block =
      if next_block_tree.parent_map != block_tree.parent_map do
        request_next_block(next_block_tree)
      else
        last_requested_block
      end

    {:noreply,
     state
     |> Map.put(:block_queue, next_block_queue)
     |> Map.put(:block_tree, next_block_tree)
     |> Map.put(:last_requested_block, new_last_requested_block)}
  end

  def handle_info({:packet, packet, peer}, state) do
    Logger.debug("[Sync] Ignoring packet #{packet.__struct__} from #{peer}")

    {:noreply, state}
  end

  def request_next_block(block_tree) do
    next_number =
      case Blockchain.Blocktree.get_canonical_block(block_tree) do
        :root -> 0
        %Blockchain.Block{header: %Block.Header{number: number}} -> number + 1
      end

    Logger.debug("[Sync] Requesting block #{next_number}")

    ExWire.PeerSupervisor.send_packet(ExWire.PeerSupervisor, %ExWire.Packet.GetBlockHeaders{
      block_identifier: next_number,
      max_headers: 1,
      skip: 0,
      reverse: false
    })

    next_number
  end
end
