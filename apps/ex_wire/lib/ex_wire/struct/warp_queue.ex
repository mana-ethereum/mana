defmodule ExWire.Struct.WarpQueue do
  @moduledoc """
  `WarpQueue` maintains the current state of an active warp, this mean we will 
  track the `block_chunk` hashes and `state_chunk` hashes given to us, so we
  can request each from our connected peers. This structure is also persisted
  during a warp sync, so that if interrupted, we can resume a warp where we
  left off.

  TODO: This will likely need to be updated to handle warping from more than
        one direct peer.
  """
  require Logger

  alias Blockchain.{Block, Blocktree}
  alias Exth.Time
  alias ExWire.Packet.Capability.Par.SnapshotManifest
  alias MerklePatriciaTree.Trie

  @type t :: %__MODULE__{
          manifest: SnapshotManifest.manifest() | nil,
          manifest_hashes: MapSet.t(EVM.hash()),
          manifest_block_hashes: MapSet.t(EVM.hash()),
          manifest_state_hashes: MapSet.t(EVM.hash()),
          chunk_requests: MapSet.t(EVM.hash()),
          retrieved_chunks: MapSet.t(EVM.hash()),
          processed_chunks: MapSet.t(EVM.hash()),
          processed_blocks: MapSet.t(integer()),
          processed_accounts: integer(),
          warp_start: Time.time(),
          block_tree: Blocktree.t(),
          state_root: EVM.hash()
        }

  defstruct [
    :manifest,
    :manifest_hashes,
    :manifest_block_hashes,
    :manifest_state_hashes,
    :chunk_requests,
    :retrieved_chunks,
    :processed_chunks,
    :processed_blocks,
    :processed_accounts,
    :warp_start,
    :block_tree,
    :state_root
  ]

  @empty_trie Trie.empty_trie_root_hash()

  @doc """
  Creates a new `WarpQueue`.
  """
  def new() do
    %__MODULE__{
      manifest: nil,
      manifest_hashes: MapSet.new(),
      manifest_block_hashes: MapSet.new(),
      manifest_state_hashes: MapSet.new(),
      chunk_requests: MapSet.new(),
      retrieved_chunks: MapSet.new(),
      processed_chunks: MapSet.new(),
      processed_blocks: MapSet.new(),
      processed_accounts: 0,
      warp_start: Time.time_start(),
      block_tree: Blocktree.new_tree(),
      state_root: @empty_trie
    }
  end

  @doc """
  Handle receiving a new manifest from a peer. The current behaviour is to
  ignore all but the first received manifest, but later on, we may add matching
  manifests to track similar peers.
  """
  @spec new_manifest(t(), SnapshotManifest.manifest()) :: t()
  def new_manifest(warp_queue, manifest) do
    if warp_queue.manifest do
      # Right now, ignore new manifests
      warp_queue
    else
      manifest_block_hashes = MapSet.new(manifest.block_hashes)
      manifest_state_hashes = MapSet.new(manifest.state_hashes)
      manifest_hashes = MapSet.union(manifest_block_hashes, manifest_state_hashes)

      %{
        warp_queue
        | manifest: manifest,
          manifest_hashes: manifest_hashes,
          manifest_block_hashes: manifest_block_hashes,
          manifest_state_hashes: manifest_state_hashes
      }
    end
  end

  @doc """
  When we receive a new block chunk, we want to remove it from requests
  and add it to our processing queue.
  """
  @spec new_block_chunk(t(), EVM.hash()) :: t()
  def new_block_chunk(warp_queue, chunk_hash) do
    updated_chunk_requests = MapSet.delete(warp_queue.chunk_requests, chunk_hash)
    updated_retrieved_chunks = MapSet.put(warp_queue.retrieved_chunks, chunk_hash)

    %{
      warp_queue
      | chunk_requests: updated_chunk_requests,
        retrieved_chunks: updated_retrieved_chunks
    }
  end

  @doc """
  When we receive a new state chunk, we simply add it to our queue, which we'll
  later process.
  """
  @spec new_state_chunk(t(), EVM.hash()) :: t()
  def new_state_chunk(warp_queue, chunk_hash) do
    updated_chunk_requests = MapSet.delete(warp_queue.chunk_requests, chunk_hash)
    updated_retrieved_chunks = MapSet.put(warp_queue.retrieved_chunks, chunk_hash)

    %{
      warp_queue
      | chunk_requests: updated_chunk_requests,
        retrieved_chunks: updated_retrieved_chunks
    }
  end

  @spec get_hashes_to_request(t(), number(), number()) :: {t(), list(EVM.hash())}
  def get_hashes_to_request(
        warp_queue = %__MODULE__{
          chunk_requests: chunk_requests,
          retrieved_chunks: retrieved_chunks,
          processed_chunks: processed_chunks
        },
        request_limit,
        queue_limit
      ) do
    queued_count =
      Enum.count(
        MapSet.difference(
          retrieved_chunks,
          processed_chunks
        )
      )

    allowed_by_parallelism = request_limit - MapSet.size(chunk_requests)
    allowed_by_queue = queue_limit - queued_count

    desired_requests = min(allowed_by_parallelism, allowed_by_queue)

    if desired_requests > 0 do
      unfetched_block_hashes =
        warp_queue.manifest_block_hashes
        |> MapSet.difference(chunk_requests)
        |> MapSet.difference(retrieved_chunks)
        |> MapSet.difference(processed_chunks)
        |> MapSet.to_list()

      unfetched_state_hashes =
        warp_queue.manifest_state_hashes
        |> MapSet.difference(chunk_requests)
        |> MapSet.difference(retrieved_chunks)
        |> MapSet.difference(processed_chunks)
        |> MapSet.to_list()

      total_unfetched_hashes = unfetched_block_hashes ++ unfetched_state_hashes
      total_unfetched_count = Enum.count(total_unfetched_hashes)

      if min(total_unfetched_count, desired_requests) > 0 do
        hashes_to_request = Enum.take(total_unfetched_hashes, desired_requests)

        :ok =
          Logger.debug(fn ->
            "[Warp] Retreiving #{Enum.count(hashes_to_request)} of #{total_unfetched_count} hash(es) needed."
          end)

        new_chunk_requests =
          MapSet.union(
            chunk_requests,
            MapSet.new(hashes_to_request)
          )

        {
          %{warp_queue | chunk_requests: new_chunk_requests},
          hashes_to_request
        }
      else
        {warp_queue, []}
      end
    else
      {warp_queue, []}
    end
  end

  @spec status(t()) :: {:pending, atom()} | :success | {:failure, atom()}
  def status(warp_queue) do
    cond do
      is_nil(warp_queue.manifest) ->
        {:pending, :no_manifest}

      MapSet.size(warp_queue.chunk_requests) > 0 ->
        {:pending, :awaiting_requests}

      !MapSet.equal?(warp_queue.manifest_hashes, warp_queue.processed_chunks) ->
        {:pending, :awaiting_processing}

      is_nil(warp_queue.block_tree.best_block) ->
        {:failure, :missing_best_block}

      warp_queue.block_tree.best_block.header.number != warp_queue.manifest.block_number ->
        :pending

      warp_queue.block_tree.best_block.block_hash != warp_queue.manifest.block_hash ->
        :ok =
          Logger.error(fn ->
            "[Warp] Mismatched block hash: expected: #{
              Exth.encode_hex(warp_queue.manifest.block_hash)
            }, got: #{Exth.encode_hex(warp_queue.block_tree.best_block.block_hash)}"
          end)

        {:failure, :mismatched_block_hash}

      warp_queue.state_root != warp_queue.manifest.state_root ->
        :ok =
          Logger.error(fn ->
            "[Warp] Mismatched state root: expected: #{
              Exth.encode_hex(warp_queue.manifest.state_root)
            }, got: #{Exth.encode_hex(warp_queue.state_root)}"
          end)

        {:failure, :mismatched_state_root}

      true ->
        :success
    end
  end

  @spec processed_state_chunk(t(), EVM.hash(), integer(), EVM.hash()) :: t()
  def processed_state_chunk(warp_queue, chunk_hash, processed_accounts, state_root) do
    next_processed_accounts = warp_queue.processed_accounts + processed_accounts

    # Show some stats for debugging
    :ok =
      Logger.debug(fn ->
        "[Warp] Completed: #{next_processed_accounts} account(s) in #{
          Time.elapsed(warp_queue.warp_start, :second)
        } at #{Time.rate(next_processed_accounts, warp_queue.warp_start, "accts", :second)} with new state root #{
          Exth.encode_hex(state_root)
        }"
      end)

    %{
      warp_queue
      | processed_accounts: next_processed_accounts,
        processed_chunks: MapSet.put(warp_queue.processed_chunks, chunk_hash),
        state_root: state_root
    }
  end

  @spec processed_block_chunk(
          t(),
          EVM.hash(),
          Block.t(),
          list(integer())
        ) :: t()
  def processed_block_chunk(warp_queue, chunk_hash, block, processed_blocks) do
    next_processed_blocks =
      MapSet.union(
        warp_queue.processed_blocks,
        MapSet.new(processed_blocks)
      )

    next_block_tree = Blocktree.update_best_block(warp_queue.block_tree, block)

    # Show some stats for debugging
    list =
      next_processed_blocks
      |> MapSet.to_list()
      |> Enum.sort()

    min = List.first(list)

    {max, missing} =
      Enum.reduce(Enum.drop(list, 1), {min, 0}, fn el, {last, count} ->
        {el, count + el - last - 1}
      end)

    :ok =
      Logger.debug(fn ->
        "[Warp] Completed: #{min}..#{max} with #{missing} missing block(s) in #{
          Time.elapsed(warp_queue.warp_start, :second)
        } at #{Time.rate(Enum.count(list), warp_queue.warp_start, "blks", :second)}"
      end)

    %{
      warp_queue
      | processed_blocks: next_processed_blocks,
        processed_chunks: MapSet.put(warp_queue.processed_chunks, chunk_hash),
        block_tree: next_block_tree
    }
  end
end
