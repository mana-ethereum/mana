defmodule ExWire.Struct.BlockQueue do
  @moduledoc """
  A structure to store and process blocks received by peers. The goal of this
  module is to keep track of partial blocks until we're ready to add the block
  to the chain.

  There are three reasons we need to keep them stored in a queue:
  1. Block headers are sent separately of block bodies. We need to store the
     headers until we receive the bodies.
  2. We shouldn't accept a block as canonical until we've heard from several
     peers that the block is the most canonical block at that number. Thus,
     we store the block and a number of commitments. Once the number of
     commitments tips over some threshold, we process the block and add it
     to our block tree.
  3. We may be waiting on a parent block as we received the child first.
     We add these blocks to a backlog map keyed by the parent hash.
  """
  alias Block.Header
  alias ExWire.Struct.Block, as: BlockStruct
  alias Blockchain.{Block, Blocktree, Chain}
  alias Blockchain.Transaction.Receipt
  alias MerklePatriciaTree.Trie

  require Logger

  @max_receipts_to_request 500
  # These will be used to help us determine if a block is empty
  @empty_trie MerklePatriciaTree.Trie.empty_trie_root_hash()
  @empty_hash [] |> ExRLP.encode() |> ExthCrypto.Hash.Keccak.kec()

  defstruct queue: %{},
            backlog: %{},
            do_validation: true,
            block_numbers: MapSet.new(),
            fast_sync_in_progress: false,
            block_receipts_set: MapSet.new(),
            block_receipts_to_request: [],
            block_receipts_requested: []

  @type block_item :: %{
          commitments: list(binary()),
          block: Block.t(),
          receipts_added: boolean(),
          ready: boolean()
        }

  @type block_map :: %{
          EVM.hash() => block_item
        }

  @type t :: %__MODULE__{
          queue: %{integer() => block_map},
          backlog: %{EVM.hash() => list(Block.t())},
          do_validation: boolean(),
          block_numbers: MapSet.t(),
          fast_sync_in_progress: boolean(),
          block_receipts_set: MapSet.t(),
          block_receipts_to_request: [EVM.hash()],
          block_receipts_requested: [EVM.hash()]
        }

  @doc """
  Adds a given header received by a peer to a block queue. Returns whether or
  not we should request the block body.

  Note: we will process it if the block is empty (i.e. has neither transactions
        nor ommers).
  """
  @spec add_header(
          t,
          Blocktree.t(),
          Header.t(),
          EVM.hash(),
          binary(),
          Chain.t(),
          Trie.t()
        ) :: {t, Blocktree.t(), Trie.t(), boolean()}
  def add_header(
        block_queue = %__MODULE__{
          queue: queue,
          fast_sync_in_progress: fast_sync_in_progress,
          block_receipts_set: block_receipts_set,
          block_receipts_to_request: block_receipts_to_request
        },
        block_tree,
        header,
        header_hash,
        remote_id,
        chain,
        trie
      ) do
    block_map = Map.get(queue, header.number, %{})
    header_num_and_hash = {header.number, header_hash}

    {block_map, should_request_body, receipts_to_request, receipts_set} =
      case Map.get(block_map, header_hash) do
        nil ->
          # may already be ready, already.
          is_empty = is_block_empty?(header)

          block_map =
            Map.put(block_map, header_hash, %{
              commitments: MapSet.new([remote_id]),
              block: %Block{header: header},
              receits_added: false,
              ready: is_empty
            })

          {receipts_set, receipts_to_request} =
            if fast_sync_in_progress do
              {
                MapSet.put(block_receipts_set, header_num_and_hash),
                [block_queue.block_receipts_to_request | header_num_and_hash]
              }
            else
              {block_receipts_set, block_receipts_to_request}
            end

          {block_map, not is_empty, receipts_to_request, receipts_set}

        block_item ->
          {receipts_set, receipts_to_request} =
            if fast_sync_in_progress and Enum.empty?(block_item.block.receipts) and
                 not MapSet.member?(block_receipts_set, header_num_and_hash) do
              {
                MapSet.put(block_receipts_set, header_num_and_hash),
                [block_queue.block_receipts_to_request | header_num_and_hash]
              }
            else
              {block_receipts_set, block_receipts_to_request}
            end

          {Map.put(block_map, header_hash, %{
             block_item
             | commitments: MapSet.put(block_item.commitments, remote_id)
           }), false, receipts_to_request, receipts_set}
      end

    updated_block_queue = %{
      block_queue
      | queue: Map.put(queue, header.number, block_map),
        block_numbers: MapSet.put(block_queue.block_numbers, header.number),
        block_receipts_set: receipts_set,
        block_receipts_to_request: receipts_to_request
    }

    {new_block_queue, new_block_tree, new_trie} =
      process_block_queue(updated_block_queue, block_tree, chain, trie)

    {new_block_queue, new_block_tree, new_trie, should_request_body}
  end

  @doc """
  Adds a given block struct received by a peer to a block queue.

  Since we don't really know which block this belongs to, we're going to just
  need to look at every block and try and guess.

  To guess, we'll compute the transactions root and ommers hash, and then try
  and find a header that matches it. For empty blocks (ones with no transactions
  and no ommers, there may be several matches. Otherwise, each block body should
  pretty much be unique).
  """
  @spec add_block_struct(
          t(),
          Blocktree.t(),
          BlockStruct.t(),
          Chain.t(),
          Trie.t()
        ) :: {t(), Blocktree.t(), Trie.t()}
  def add_block_struct(
        block_queue = %__MODULE__{queue: queue},
        block_tree,
        block_struct,
        chain,
        trie
      ) do
    transactions_root = get_transactions_root(block_struct.transactions_rlp)
    ommers_hash = get_ommers_hash(block_struct.ommers_rlp)

    updated_queue =
      Enum.reduce(queue, queue, fn {number, block_map}, queue ->
        updated_block_map =
          Enum.reduce(block_map, block_map, fn {hash, block_item}, block_map ->
            if block_item.block.header.transactions_root == transactions_root and
                 block_item.block.header.ommers_hash == ommers_hash do
              # This is now ready! (though, it may not still have enough commitments)
              block = %{
                block_item.block
                | transactions: block_struct.transactions,
                  ommers: block_struct.ommers
              }

              Map.put(block_map, hash, %{block_item | block: block, ready: true})
            else
              block_map
            end
          end)

        Map.put(queue, number, updated_block_map)
      end)

    updated_block_queue = %{block_queue | queue: updated_queue}

    process_block_queue(updated_block_queue, block_tree, chain, trie)
  end

  @doc """
  Returns the collection of block hashes for which Receipts are needed, as well as the
  updated BlockQueue accounting for the requested hashes, if fast sync is in progress and
  a request is not already in flight.
  """
  @spec get_receipts_to_request(t()) :: {:ok, [EVM.hash()], t()} | :do_not_request
  def get_receipts_to_request(
        block_queue = %__MODULE__{
          fast_sync_in_progress: is_fast,
          block_receipts_to_request: to_request,
          block_receipts_requested: requested
        }
      ) do
    if is_fast and Enum.empty?(requested) and not Enum.empty?(to_request) do
      {new_requests, to_request_tail} = Enum.split(to_request, @max_receipts_to_request)

      {
        :ok,
        new_requests |> Enum.map(fn {_number, hash} -> hash end),
        %{
          block_queue
          | block_receipts_to_request: to_request_tail,
            block_receipts_requested: new_requests
        }
      }
    else
      # TODO: check if we're done with Fast Sync and update BlockQueue.fast_sync_in_progress
      :do_not_request
    end
  end

  @doc """
  Processes the provided Receipts, verifying them against stored Headers and adding
  them to the Blocks stored in the BlockQueue.
  This will return the updated BlockQueue and the hashes of the blocks to request Receipts for next.
  """
  @spec add_receipts(t(), [[Receipt.t()]]) :: {t(), [EVM.hash()]} | {t(), []}
  def add_receipts(queue = %__MODULE__{block_receipts_requested: req}, receipts)
      when length(req) != length(receipts) do
    :ok =
      Logger.warn(fn ->
        "[Block Queue] Received Receipts of different length than requested. Cannot match them to blocks. Receipts # [#{
          Enum.count(receipts)
        }], Requested # [#{Enum.count(req)}]"
      end)

    {queue, req}
  end

  def add_receipts(
        block_queue = %__MODULE__{
          queue: queue,
          block_receipts_set: block_receipts_set,
          block_receipts_requested: requested
        },
        block_receipts
      ) do
    number_hash_tuple_receipts = Enum.zip(requested, block_receipts)

    updated_queue =
      Enum.reduce(number_hash_tuple_receipts, block_queue, fn {{number, hash}, receipts},
                                                              updated_queue ->
        block_map = Map.get(queue, number)
        block_item = Map.get(block_map, hash)
        block = Map.get(block_item, :block)
        updated_block = %{block | receipts: receipts}

        # TODO: Build Trie and verify that Receipts Root matches header.receipts_root

        Map.put(
          updated_queue,
          number,
          Map.put(block_map, hash, %{
            block_item
            | receipts_added: true,
              block: updated_block
          })
        )
      end)

    updated_receipts_set = MapSet.difference(block_receipts_set, MapSet.new(requested))

    updated_block_queue = %{
      block_queue
      | queue: updated_queue,
        block_receipts_requested: [],
        block_receipts_set: updated_receipts_set
    }

    case get_receipts_to_request(updated_block_queue) do
      {:ok, hashes, block_queue_to_return} ->
        {block_queue_to_return, hashes}

      :do_not_request ->
        {updated_block_queue, []}
    end
  end

  @doc """
  Processes a the block queue, adding any blocks which are complete and pass
  the number of confirmations to the block tree. These blocks are then removed
  from the queue. Note: they may end up in the backlog, nonetheless, if we are
  waiting still for the parent block.
  """
  @spec process_block_queue(t(), Blocktree.t(), Chain.t(), Trie.t()) ::
          {t(), Blocktree.t(), Trie.t()}
  def process_block_queue(
        block_queue = %__MODULE__{},
        block_tree,
        chain,
        trie
      ) do
    # First get ready to process blocks
    {remaining_block_queue, blocks} = get_complete_blocks(block_queue)

    # Then recursively process them
    do_process_blocks(blocks, remaining_block_queue, block_tree, chain, trie)
  end

  @spec do_process_blocks(list(Block.t()), t(), Blocktree.t(), Chain.t(), Trie.t()) ::
          {t(), Blocktree.t(), Trie.t()}

  defp do_process_blocks([], block_queue, block_tree, _chain, trie),
    do: {block_queue, block_tree, trie}

  defp do_process_blocks(
         [block | rest],
         block_queue = %__MODULE__{fast_sync_in_progress: true},
         block_tree,
         chain,
         trie
       ) do
    {:ok, {updated_blocktree, updated_trie, block_hash}} =
      Blocktree.add_block_without_validation(block_tree, block, trie)

    :ok =
      Logger.debug(fn ->
        "[Block Queue] Added block #{block.header.number} (0x#{
          Base.encode16(block_hash, case: :lower)
        }) to new block tree without validation during fast sync."
      end)

    {backlogged_blocks, new_backlog} = Map.pop(block_queue.backlog, block_hash, [])

    new_block_queue = %{block_queue | backlog: new_backlog}

    do_process_blocks(
      backlogged_blocks ++ rest,
      new_block_queue,
      updated_blocktree,
      chain,
      updated_trie
    )
  end

  defp do_process_blocks([block | rest], block_queue, block_tree, chain, trie) do
    {new_block_tree, new_trie, new_backlog, extra_blocks} =
      case Blocktree.verify_and_add_block(
             block_tree,
             chain,
             block,
             trie,
             block_queue.do_validation
           ) do
        {:invalid, [:non_genesis_block_requires_parent]} ->
          # Note: this is probably too slow since we see a lot of blocks without
          #       parents and, I think, we're running the full validity check.

          # :ok = Logger.debug("[Block Queue] Failed to verify block due to missing parent")

          updated_backlog =
            Map.update(
              block_queue.backlog,
              block.header.parent_hash,
              [block],
              fn blocks -> [block | blocks] end
            )

          {block_tree, trie, updated_backlog, []}

        {:invalid, reasons} ->
          :ok =
            Logger.debug(fn ->
              "[Block Queue] Failed to verify block due to #{inspect(reasons)}"
            end)

          {block_tree, trie, block_queue.backlog, []}

        {:ok, {new_block_tree, new_trie, block_hash}} ->
          :ok =
            Logger.debug(fn ->
              "[Block Queue] Verified block #{block.header.number} (0x#{
                Base.encode16(block_hash, case: :lower)
              }) and added to new block tree"
            end)

          {backlogged_blocks, new_backlog} = Map.pop(block_queue.backlog, block_hash, [])

          {new_block_tree, new_trie, new_backlog, backlogged_blocks}
      end

    new_block_queue = %{block_queue | backlog: new_backlog}

    do_process_blocks(extra_blocks ++ rest, new_block_queue, new_block_tree, chain, new_trie)
  end

  @doc """
  Returns the set of blocks which are complete in the block queue, returning a
  new block queue with those blocks removed. This effective dequeues blocks
  once they have sufficient data and commitments. These blocks may still
  fail to process or end up in a backlog if the parent is missing.

  ## Examples

      iex> %ExWire.Struct.BlockQueue{
      ...>   queue: %{
      ...>     5 => %{
      ...>       <<1::256>> => %{
      ...>         commitments: MapSet.new([1, 2]),
      ...>         header: %Block.Header{number: 5},
      ...>         block: %Blockchain.Block{block_hash: <<1::256>>},
      ...>         ready: true,
      ...>       },
      ...>       <<2::256>> => %{
      ...>         commitments: MapSet.new([]),
      ...>         header: %Block.Header{number: 5},
      ...>         block: %Blockchain.Block{block_hash: <<2::256>>},
      ...>         ready: true,
      ...>       },
      ...>       <<3::256>> => %{
      ...>         commitments: MapSet.new([1, 2]),
      ...>         header: %Block.Header{number: 5, gas_used: 5},
      ...>         block: %Blockchain.Block{block_hash: <<3::256>>},
      ...>         ready: false,
      ...>       },
      ...>       <<4::256>> => %{
      ...>         commitments: MapSet.new([1, 2]),
      ...>         header: %Block.Header{number: 5, ommers_hash: <<5::256>>},
      ...>         block: %Blockchain.Block{block_hash: <<4::256>>},
      ...>         ready: false,
      ...>       }
      ...>     },
      ...>     6 => %{
      ...>       <<5::256>> => %{
      ...>         commitments: MapSet.new([1, 2]),
      ...>         header: %Block.Header{number: 6},
      ...>         block: %Blockchain.Block{block_hash: <<5::256>>},
      ...>         ready: true,
      ...>       }
      ...>     }
      ...>   }
      ...> }
      ...> |> ExWire.Struct.BlockQueue.get_complete_blocks()
      {
        %ExWire.Struct.BlockQueue{
          queue: %{
            5 => %{
              <<2::256>> => %{
                commitments: MapSet.new([]),
                header: %Block.Header{number: 5},
                block: %Blockchain.Block{block_hash: <<2::256>>},
                ready: true
              },
              <<3::256>> => %{
                commitments: MapSet.new([1, 2]),
                header: %Block.Header{number: 5, gas_used: 5},
                block: %Blockchain.Block{block_hash: <<3::256>>},
                ready: false
              },
              <<4::256>> => %{
                commitments: MapSet.new([1, 2]),
                header: %Block.Header{number: 5, ommers_hash: <<5::256>>},
                block: %Blockchain.Block{block_hash: <<4::256>>},
                ready: false
              }
            }
          }
        },
        [
          %Blockchain.Block{block_hash: <<1::256>>},
          %Blockchain.Block{block_hash: <<5::256>>}
        ]
      }
  """
  @spec get_complete_blocks(t) :: {t, [Block.t()]}
  def get_complete_blocks(
        block_queue = %__MODULE__{queue: queue, fast_sync_in_progress: fast_syncing}
      ) do
    {queue, blocks} =
      Enum.reduce(queue, {queue, []}, fn {number, block_map}, {queue, blocks} ->
        {final_block_map, new_blocks} =
          Enum.reduce(block_map, {block_map, []}, fn {hash, block_item}, {block_map, blocks} ->
            if block_item.ready and (not fast_syncing or block_item.receipts_added) and
                 MapSet.size(block_item.commitments) >= ExWire.Config.commitment_count() do
              {Map.delete(block_map, hash), [block_item.block | blocks]}
            else
              {block_map, blocks}
            end
          end)

        total_blocks = blocks ++ new_blocks

        if final_block_map == %{} do
          {Map.delete(queue, number), total_blocks}
        else
          {Map.put(queue, number, final_block_map), total_blocks}
        end
      end)

    {%{block_queue | queue: queue}, blocks}
  end

  @doc """
  Determines if a block is empty. There's no reason to actually ask for a block
  body if we know, a priori, that the block is empty.

  ## Examples

      iex> %Block.Header{
      ...>   transactions_root: MerklePatriciaTree.Trie.empty_trie_root_hash(),
      ...>   ommers_hash: <<29, 204, 77, 232, 222, 199, 93, 122, 171, 133, 181, 103, 182, 204, 212, 26, 211, 18, 69, 27, 148, 138, 116, 19, 240, 161, 66, 253, 64, 212, 147, 71>>
      ...> }
      ...> |> ExWire.Struct.BlockQueue.is_block_empty?
      true

      iex> %Block.Header{
      ...>   transactions_root: MerklePatriciaTree.Trie.empty_trie_root_hash(),
      ...>   ommers_hash: <<1>>
      ...> }
      ...> |> ExWire.Struct.BlockQueue.is_block_empty?
      false

      iex> %Block.Header{
      ...>   transactions_root: <<1>>,
      ...>   ommers_hash: <<29, 204, 77, 232, 222, 199, 93, 122, 171, 133, 181, 103, 182, 204, 212, 26, 211, 18, 69, 27, 148, 138, 116, 19, 240, 161, 66, 253, 64, 212, 147, 71>>
      ...> }
      ...> |> ExWire.Struct.BlockQueue.is_block_empty?
      false
  """
  @spec is_block_empty?(Header.t()) :: boolean()
  def is_block_empty?(header) do
    header.transactions_root == @empty_trie and header.ommers_hash == @empty_hash
  end

  # Tries to get the transaction root by encoding the transaction trie
  @spec get_transactions_root([ExRLP.t()]) :: MerklePatriciaTree.Trie.root_hash()
  defp get_transactions_root(transactions_rlp) do
    # this is a throw-away
    db = MerklePatriciaTree.Test.random_ets_db()

    trie =
      Enum.reduce(transactions_rlp |> Enum.with_index(), Trie.new(db), fn {trx, i}, trie ->
        Trie.update_key(trie, ExRLP.encode(i), ExRLP.encode(trx))
      end)

    trie.root_hash
  end

  @spec get_ommers_hash(list(binary())) :: ExthCrypto.Hash.hash()
  defp get_ommers_hash(ommers_rlp) do
    ommers_rlp
    |> ExRLP.encode()
    |> ExthCrypto.Hash.Keccak.kec()
  end
end
