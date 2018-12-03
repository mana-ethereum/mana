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
  require Logger

  alias Block.Header
  alias ExWire.Struct.Block, as: BlockStruct
  alias ExWire.Struct.Peer
  alias Blockchain.{Block, Blocktree}
  alias MerklePatriciaTree.Trie

  alias ExWire.Packet.Capability.Eth.{
    BlockBodies,
    BlockHeaders,
    NodeData,
    Receipts
  }

  # These will be used to help us determine if a block is empty
  @empty_trie MerklePatriciaTree.Trie.empty_trie_root_hash()
  @empty_hash [] |> ExRLP.encode() |> ExthCrypto.Hash.Keccak.kec()

  defstruct queue: %{},
            block_numbers: MapSet.new(),
            needed_block_hashes: [],
            max_header_request: nil,
            header_requests: MapSet.new(),
            block_requests: MapSet.new(),
            block_tree: Blocktree.new_tree(),
            processing_blocks: MapSet.new()

  @type block_item :: %{
          commitments: list(binary()),
          block: Block.t(),
          ready: boolean()
        }

  @type block_map :: %{
          EVM.hash() => block_item
        }

  @type request :: {:header, integer()} | {:block, list(EVM.hash())}

  @type t :: %__MODULE__{
          queue: %{integer() => block_map},
          block_numbers: MapSet.t(integer()),
          needed_block_hashes: list(EVM.hash()),
          max_header_request: nil | integer(),
          header_requests: MapSet.t(integer()),
          block_requests: MapSet.t(EVM.hash()),
          block_tree: Blocktree.t(),
          processing_blocks: %{EVM.hash() => Block.t()}
        }

  @headers_per_request 15

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
        block_queue = %__MODULE__{queue: queue, processing_blocks: processing_blocks}
      ) do
    {next_queue, next_processing_blocks, blocks} =
      Enum.reduce(queue, {queue, processing_blocks, []}, fn {number, block_map},
                                                            {curr_queue, curr_processing_blocks,
                                                             blocks} ->
        {final_block_map, new_blocks, next_processing_blocks} =
          Enum.reduce(block_map, {block_map, [], curr_processing_blocks}, fn {hash, block_item},
                                                                             {block_map, blocks,
                                                                              inner_curr_processing_blocks} ->
            if block_item.ready and
                 MapSet.size(block_item.commitments) >= ExWire.Config.commitment_count() do
              {Map.delete(block_map, hash), [block_item.block | blocks],
               Map.put(inner_curr_processing_blocks, hash, block_item.block)}
            else
              {block_map, blocks, inner_curr_processing_blocks}
            end
          end)

        total_blocks = blocks ++ new_blocks

        next_queue =
          if final_block_map == %{} do
            Map.delete(curr_queue, number)
          else
            Map.put(curr_queue, number, final_block_map)
          end

        {next_queue, next_processing_blocks, total_blocks}
      end)

    {%{block_queue | queue: next_queue, processing_blocks: next_processing_blocks}, blocks}
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

  @doc """
  Determines the next block we don't yet have in our blocktree and
  dispatches a request to all connected peers for that block and the
  next `n` blocks after it.
  """
  @spec get_requests(BlockQueue.t()) :: list(request())
  def get_requests(block_queue) do
    requests = []

    # TODO: Consider this conditional logic
    {next_block_queue, requests} =
      if MapSet.size(block_queue.header_requests) > 5 ||
           Enum.count(block_queue.needed_block_hashes) > 5 do
        {block_queue, requests}
      else
        highest_request =
          if is_nil(block_queue.max_header_request) do
            if is_nil(block_queue.block_tree.best_block) do
              0
            else
              0
            end
          else
            0
          end

        {
          %{
            block_queue
            | header_requests:
                MapSet.union(
                  block_queue.header_requests,
                  MapSet.new(highest_request..(highest_request + @headers_per_request))
                ),
              max_header_request: highest_request + @headers_per_request
          },
          [{:headers, highest_request, @headers_per_request} | requests]
        }
      end

    {next_block_queue_2, requests} =
      if Enum.count(next_block_queue.needed_block_hashes) == 0 do
        {next_block_queue, requests}
      else
        {
          %{
            next_block_queue
            | needed_block_hashes: [],
              block_requests:
                MapSet.union(
                  next_block_queue.block_requests,
                  MapSet.new(next_block_queue.needed_block_hashes)
                )
          },
          [{:bodies, next_block_queue.needed_block_hashes} | requests]
        }
      end

    {
      next_block_queue_2,
      Enum.reverse(requests)
    }
  end

  @doc """
  Adds new block headers to the block queue.
  """
  @spec new_block_headers(t(), BlockHeaders.t(), Peer.t()) :: t()
  def new_block_headers(
        block_queue = %__MODULE__{},
        %BlockHeaders{headers: headers},
        peer
      ) do
    Enum.reduce(headers, block_queue, fn header, curr_block_queue ->
      header_hash = Header.hash(header)
      bq = add_header(curr_block_queue, header, header_hash, peer.remote_id)
      IO.inspect(["Queue Size", Enum.count(bq.queue)])
      bq
    end)
  end

  @doc """
  Adds new block bodies to the block queue.
  """
  @spec new_block_bodies(t(), BlockBodies.t()) :: t()
  def new_block_bodies(
        block_queue = %__MODULE__{},
        %BlockBodies{blocks: blocks}
      ) do
    Enum.reduce(blocks, block_queue, fn block_body, curr_block_queue ->
      add_block_struct(curr_block_queue, block_body)
    end)
  end

  @doc """
  Adds new node data to the block queue.
  """
  @spec new_node_data(t(), NodeData.t()) :: t()
  def new_node_data(
        block_queue = %__MODULE__{},
        %NodeData{values: values}
      ) do
    :ok =
      Exth.trace(fn ->
        "#{__MODULE__} Got and ignoring #{Enum.count(values)} node data value(s)."
      end)

    block_queue
  end

  @doc """
  Adds new receipts to the block queue.
  """
  @spec new_receipts(t(), Receipts.t()) :: t()
  def new_receipts(
        block_queue = %__MODULE__{},
        %Receipts{receipts: receipts}
      ) do
    :ok =
      Exth.trace(fn -> "#{__MODULE__} Got and ignoring #{Enum.count(receipts)} receipt(s)." end)

    block_queue
  end

  # Adds a given header received by a peer to a block queue. Returns whether or
  # not we should request the block body.

  # Note: we will process it if the block is empty (i.e. has neither transactions
  #       nor ommers).
  @spec add_header(t(), Header.t(), EVM.hash(), binary()) :: t()
  def add_header(
        block_queue = %__MODULE__{
          queue: queue,
          needed_block_hashes: needed_block_hashes
        },
        header,
        header_hash,
        remote_id
      ) do
    block_map = Map.get(queue, header.number, %{})

    {next_block_map, next_needed_block_hashes} =
      case Map.get(block_map, header_hash) do
        nil ->
          # may already be ready, already.
          is_empty = is_block_empty?(header)

          next_block_map_inner =
            Map.put(block_map, header_hash, %{
              commitments: MapSet.new([remote_id]),
              block: %Block{header: header},
              ready: is_empty
            })

          next_needed_block_hashes =
            if is_empty do
              needed_block_hashes
            else
              [header_hash | needed_block_hashes]
            end

          {next_block_map_inner, next_needed_block_hashes}

        block_item ->
          {Map.put(block_map, header_hash, %{
             block_item
             | commitments: MapSet.put(block_item.commitments, remote_id)
           }), needed_block_hashes}
      end

    %{
      block_queue
      | queue: Map.put(queue, header.number, next_block_map |> IO.inspect()),
        block_numbers: MapSet.put(block_queue.block_numbers, header.number),
        needed_block_hashes: next_needed_block_hashes,
        header_requests: MapSet.delete(block_queue.header_requests, header.number)
    }
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
          BlockStruct.t()
        ) :: t()
  def add_block_struct(
        block_queue = %__MODULE__{
          queue: queue
        },
        block_struct
      ) do
    transactions_root = get_transactions_root(block_struct.transactions_rlp)
    ommers_hash = get_ommers_hash(block_struct.ommers_rlp)
    Exth.inspect(queue, "queue")

    updated_queue =
      Enum.reduce(queue, queue, fn {number, block_map}, curr_queue ->
        updated_block_map =
          Enum.reduce(block_map, block_map, fn {hash, block_item}, curr_block_map ->
            if block_item.block.header.transactions_root == transactions_root and
                 block_item.block.header.ommers_hash == ommers_hash do
              IO.inspect("yes")
              # This is now ready! (though, it may not still have enough commitments)
              block = %{
                block_item.block
                | transactions: block_struct.transactions,
                  ommers: block_struct.ommers
              }

              Map.put(curr_block_map, hash, %{block_item | block: block, ready: true})
            else
              IO.inspect("no")
              curr_block_map
            end
          end)

        Map.put(curr_queue, number, updated_block_map)
      end)

    %{block_queue | queue: updated_queue |> Exth.inspect("new queue")}
  end

  @spec processed_blocks(t(), list(EVM.hash()), Block.t()) :: t()
  def processed_blocks(
        block_queue = %{
          block_tree: block_tree,
          processing_blocks: processing_blocks
        },
        block_hashes,
        best_block
      ) do
    next_processing_blocks =
      Enum.reduce(block_hashes, processing_blocks, fn block_hash, curr_processing_blocks ->
        Map.delete(curr_processing_blocks, block_hash)
      end)

    next_block_tree =
      if best_block do
        Blocktree.update_best_block(block_tree, best_block)
      else
        block_tree
      end

    %{block_queue | processing_blocks: next_processing_blocks, block_tree: next_block_tree}
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
