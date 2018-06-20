defmodule ExWire.Struct.BlockQueue do
  @moduledoc """
  A structure to store and process blocks received by peers. The goal of this module
  is to keep track of partial blocks until we're ready to add the block to the chain.

  There are two reasons we need to keep them stored in a queue:
  1. Block headers are sent separately of block bodies. We need to store the
     headers until we receive the bodies.
  2. We shouldn't accept a block as canonical until we've heard from several
     peers that the block is the most canonical block at that number. Thus,
     we store the block and a number of commitments. Once the number of
     commitments tips over some threshold, we process the block and add it
     to our block tree.
  """

  alias EthCore.Block.Header
  alias ExWire.Struct.Block, as: BlockStruct
  alias Blockchain.{Block, Blocktree, Chain}
  alias MerklePatriciaTree.Trie

  require Logger

  # These will be used to help us determine if a block is empty
  @empty_trie MerklePatriciaTree.Trie.empty_trie_root_hash()
  @empty_hash [] |> ExRLP.encode() |> ExthCrypto.Hash.Keccak.kec()

  defstruct queue: %{},
            do_validation: true

  @type block_item :: %{
          commitments: [binary()],
          block: Block.t(),
          ready: boolean()
        }

  @type block_map :: %{
          EVM.hash() => block_item
        }

  @type t :: %__MODULE__{
          queue: %{integer() => block_map},
          do_validation: boolean()
        }

  @doc """
  Adds a given header received by a peer to a block queue. Returns wether or not we should
  request the block body, as well.

  Note: we will process it if the block is empty (i.e. has no transactions nor ommers).

  ## Examples

      iex> chain = Blockchain.Chain.load_chain(:ropsten)
      iex> db = MerklePatriciaTree.Test.random_ets_db(:proces_block_queue)
      iex> header = %EthCore.Block.Header{number: 5, parent_hash: <<0::256>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}
      iex> header_hash = <<78, 28, 127, 10, 192, 253, 127, 239, 254, 179, 39, 34, 245, 44, 152, 98, 128, 71, 238, 155, 100, 161, 199, 71, 243, 223, 172, 191, 74, 99, 128, 63>>
      iex> {block_queue, block_tree, false} = ExWire.Struct.BlockQueue.add_header(%ExWire.Struct.BlockQueue{do_validation: false}, Blockchain.Blocktree.new(), header, header_hash, "remote_id", chain, db)
      iex> block_queue.queue
      %{}
      iex> block_tree.parent_map
      %{<<109, 191, 166, 180, 1, 44, 85, 48, 107, 43, 51, 4, 81, 128, 110, 188, 130, 1, 5, 255, 21, 204, 250, 214, 105, 55, 182, 104, 0, 94, 102, 6>> => <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>}

      # TODO: Add a second addition example
  """
  @spec add_header(
          t,
          Blocktree.t(),
          Header.t(),
          EVM.hash(),
          binary(),
          Chain.t(),
          MerklePatriciaTree.DB.db()
        ) :: {t, Blocktree.t(), boolean()}
  def add_header(
        block_queue = %__MODULE__{queue: queue},
        block_tree,
        header,
        header_hash,
        remote_id,
        chain,
        db
      ) do
    block_map = Map.get(queue, header.number, %{})

    {block_map, should_request_body} =
      case Map.get(block_map, header_hash) do
        nil ->
          # may already be ready, already.
          is_empty = is_block_empty?(header)

          block_map =
            Map.put(block_map, header_hash, %{
              commitments: MapSet.new([remote_id]),
              block: %Block{header: header},
              ready: is_empty
            })

          {block_map, not is_empty}

        block_item ->
          {Map.put(block_map, header_hash, %{
             block_item
             | commitments: MapSet.put(block_item.commitments, remote_id)
           }), false}
      end

    updated_block_queue = %{block_queue | queue: Map.put(queue, header.number, block_map)}

    {block_queue, block_tree} = process_block_queue(updated_block_queue, block_tree, chain, db)

    {block_queue, block_tree, should_request_body}
  end

  @doc """
  Adds a given block struct received by a peer to a block queue.

  Since we don't really know which block this belongs to, we're going to just
  need to look at every block and try and guess.

  To guess, we'll compute the transactions root and ommers hash, and then try
  and find a header that matches it. For empty blocks (ones with no transactions
  and no ommers, there may be several matches. Otherwise, each block body should
  pretty much be unique).

  ## Examples

      iex> chain = Blockchain.Chain.load_chain(:ropsten)
      iex> db = MerklePatriciaTree.Test.random_ets_db(:add_block_struct)
      iex> header = %EthCore.Block.Header{
      ...>   transactions_root: <<200, 70, 164, 239, 152, 124, 5, 149, 40, 10, 157, 9, 210, 181, 93, 89, 5, 119, 158, 112, 221, 58, 94, 86, 206, 113, 120, 51, 241, 9, 154, 150>>,
      ...>   ommers_hash: <<232, 5, 101, 202, 108, 35, 61, 149, 228, 58, 111, 18, 19, 234, 191, 129, 189, 107, 167, 195, 222, 123, 50, 51, 176, 222, 225, 181, 72, 231, 198, 53>>
      ...> }
      iex> block_struct = %ExWire.Struct.Block{
      ...>   transactions_list: [[1], [2], [3]],
      ...>   transactions: ["trx"],
      ...>   ommers: ["ommers"]
      ...> }
      iex> block_queue = %ExWire.Struct.BlockQueue{
      ...>   queue: %{
      ...>     1 => %{
      ...>       <<1::256>> => %{
      ...>         commitments: MapSet.new([]),
      ...>         header: header,
      ...>         block: %Blockchain.Block{header: header, block_hash: <<1::256>>},
      ...>         ready: false,
      ...>       }
      ...>     }
      ...>   },
      ...>   do_validation: false
      ...> }
      iex> {block_queue, _block_tree} = ExWire.Struct.BlockQueue.add_block_struct(
      ...>   block_queue,
      ...>   Blockchain.Blocktree.new(),
      ...>   block_struct,
      ...>   chain,
      ...>   db
      ...> )
      iex> block_queue.queue[1][<<1::256>>].block.transactions
      ["trx"]
      iex> block_queue.queue[1][<<1::256>>].block.ommers
      ["ommers"]
  """
  @spec add_block_struct(
          t,
          BlockStruct.t(),
          Blocktree.t(),
          Chain.t(),
          MerklePatriciaTree.DB.db()
        ) :: t
  def add_block_struct(
        block_queue = %__MODULE__{queue: queue},
        block_tree,
        block_struct,
        chain,
        db
      ) do
    transactions_root = get_transactions_root(block_struct.transactions_list)
    ommers_hash = get_ommers_hash(block_struct.ommers)

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

    process_block_queue(updated_block_queue, block_tree, chain, db)
  end

  @doc """
  Processes a the block queue, adding any blocks which are complete and pass the number
  of confirmations to the block tree. Those are then removed from the queue.

  ## Examples

      iex> chain = Blockchain.Chain.load_chain(:ropsten)
      iex> db = MerklePatriciaTree.Test.random_ets_db(:process_block_queue)
      iex> header = %EthCore.Block.Header{number: 1, parent_hash: <<0::256>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}
      iex> {block_queue, block_tree} = %ExWire.Struct.BlockQueue{
      ...>   queue: %{
      ...>     1 => %{
      ...>       <<1::256>> => %{
      ...>         commitments: MapSet.new([1, 2]),
      ...>         header: header,
      ...>         block: %Blockchain.Block{header: header, block_hash: <<1::256>>},
      ...>         ready: true,
      ...>       }
      ...>     }
      ...>   },
      ...>   do_validation: false
      ...> }
      ...> |> ExWire.Struct.BlockQueue.process_block_queue(Blockchain.Blocktree.new(), chain, db)
      iex> block_tree.parent_map
      %{<<226, 210, 216, 149, 139, 194, 100, 151, 35, 86, 131, 75, 10, 203, 201, 20, 232, 134, 23, 195, 24, 34, 181, 6, 142, 4, 57, 85, 121, 223, 246, 87>> => <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>}
      iex> block_queue.queue
      %{}
  """
  @spec process_block_queue(t, Blocktree.t(), Chain.t(), MerklePatriciaTree.DB.db()) ::
          {t, Blocktree.t()}
  def process_block_queue(
        block_queue = %__MODULE__{do_validation: do_validation},
        block_tree,
        chain,
        db
      ) do
    # We can only process the next canonical block

    {remaining_block_queue, blocks} = get_complete_blocks(block_queue)

    block_tree =
      Enum.reduce(blocks, block_tree, fn block, block_tree ->
        case Blocktree.verify_and_add_block(
               block_tree,
               chain,
               block,
               db,
               do_validation
             ) do
          :parent_not_found ->
            Logger.debug("[Block Queue] Failed to verify block due to missing parent")

            block_tree

          {:invalid, reasons} ->
            Logger.debug("[Block Queue] Failed to verify block due to #{inspect(reasons)}")

            block_tree

          {:ok, new_block_tree} ->
            Logger.debug("[Block Queue] Verified block and added to new block tree")

            new_block_tree
        end
      end)

    {remaining_block_queue, block_tree}
  end

  @doc """
  Returns the set of blocks which are complete in the block queue, returning a new block queue
  with those blocks removed. This effective dequeues blocks once they have sufficient data and
  commitments.

  ## Examples

      iex> %ExWire.Struct.BlockQueue{
      ...>   queue: %{
      ...>     5 => %{
      ...>       <<1::256>> => %{
      ...>         commitments: MapSet.new([1, 2]),
      ...>         header: %EthCore.Block.Header{number: 5},
      ...>         block: %Blockchain.Block{block_hash: <<1::256>>},
      ...>         ready: true,
      ...>       },
      ...>       <<2::256>> => %{
      ...>         commitments: MapSet.new([]),
      ...>         header: %EthCore.Block.Header{number: 5},
      ...>         block: %Blockchain.Block{block_hash: <<2::256>>},
      ...>         ready: true,
      ...>       },
      ...>       <<3::256>> => %{
      ...>         commitments: MapSet.new([1, 2]),
      ...>         header: %EthCore.Block.Header{number: 5, gas_used: 5},
      ...>         block: %Blockchain.Block{block_hash: <<3::256>>},
      ...>         ready: false,
      ...>       },
      ...>       <<4::256>> => %{
      ...>         commitments: MapSet.new([1, 2]),
      ...>         header: %EthCore.Block.Header{number: 5, ommers_hash: <<5::256>>},
      ...>         block: %Blockchain.Block{block_hash: <<4::256>>},
      ...>         ready: false,
      ...>       }
      ...>     },
      ...>     6 => %{
      ...>       <<5::256>> => %{
      ...>         commitments: MapSet.new([1, 2]),
      ...>         header: %EthCore.Block.Header{number: 6},
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
                header: %EthCore.Block.Header{number: 5},
                block: %Blockchain.Block{block_hash: <<2::256>>},
                ready: true
              },
              <<3::256>> => %{
                commitments: MapSet.new([1, 2]),
                header: %EthCore.Block.Header{number: 5, gas_used: 5},
                block: %Blockchain.Block{block_hash: <<3::256>>},
                ready: false
              },
              <<4::256>> => %{
                commitments: MapSet.new([1, 2]),
                header: %EthCore.Block.Header{number: 5, ommers_hash: <<5::256>>},
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
  def get_complete_blocks(block_queue = %__MODULE__{queue: queue}) do
    {queue, blocks} =
      Enum.reduce(queue, {queue, []}, fn {number, block_map}, {queue, blocks} ->
        {final_block_map, new_blocks} =
          Enum.reduce(block_map, {block_map, []}, fn {hash, block_item}, {block_map, blocks} ->
            if block_item.ready and
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
  body if we know, a priori, that a block is empty.

  ## Examples

      iex> %EthCore.Block.Header{
      ...>   transactions_root: MerklePatriciaTree.Trie.empty_trie_root_hash(),
      ...>   ommers_hash: <<29, 204, 77, 232, 222, 199, 93, 122, 171, 133, 181, 103, 182, 204, 212, 26, 211, 18, 69, 27, 148, 138, 116, 19, 240, 161, 66, 253, 64, 212, 147, 71>>
      ...> }
      ...> |> ExWire.Struct.BlockQueue.is_block_empty?
      true

      iex> %EthCore.Block.Header{
      ...>   transactions_root: MerklePatriciaTree.Trie.empty_trie_root_hash(),
      ...>   ommers_hash: <<1>>
      ...> }
      ...> |> ExWire.Struct.BlockQueue.is_block_empty?
      false

      iex> %EthCore.Block.Header{
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

  @spec get_transactions_root([ExRLP.t()]) :: MerklePatriciaTree.Trie.root_hash()
  defp get_transactions_root(transactions_list) do
    # this is a throw-away
    db = MerklePatriciaTree.Test.random_ets_db()

    trie =
      Enum.reduce(transactions_list |> Enum.with_index(), Trie.new(db), fn {trx, i}, trie ->
        Trie.update(trie, ExRLP.encode(i), ExRLP.encode(trx))
      end)

    trie.root_hash
  end

  @spec get_ommers_hash([EVM.hash()]) :: ExthCrypto.hash()
  defp get_ommers_hash(ommers) do
    ommers |> ExRLP.encode() |> ExthCrypto.Hash.Keccak.kec()
  end
end
