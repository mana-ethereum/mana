defmodule ExWire.Sync.BlockProcessor.StandardProcessor do
  @moduledoc """

  """
  require Logger

  alias Blockchain.{Block, Blocktree, Chain}
  alias ExWire.Sync.BlockProcessor
  alias MerklePatriciaTree.Trie

  @behaviour BlockProcessor

  @doc """
  Processes a the block queue, adding any blocks which are complete and pass
  the number of confirmations to the block tree. These blocks are then removed
  from the queue. Note: they may end up in the backlog, nonetheless, if we are
  waiting still for the parent block.
  """
  @spec process_blocks(
          list(Block.t()),
          Blocktree.t(),
          BlockProcessor.backlog(),
          Chain.t(),
          Trie.t(),
          boolean()
        ) :: {list(EVM.hash()), Blocktree.t(), BlockProcessor.backlog(), Trie.t()}
  def process_blocks(
        blocks,
        block_tree,
        backlog,
        chain,
        trie,
        do_validation
      ) do
    do_process_blocks(blocks, [], block_tree, backlog, chain, trie, do_validation)
  end

  @spec do_process_blocks(
          list(Block.t()),
          list(EVM.hash()),
          Blocktree.t(),
          BlockProcessor.backlog(),
          Chain.t(),
          Trie.t(),
          boolean()
        ) :: {list(EVM.hash()), Blocktree.t(), BlockProcessor.backlog(), Trie.t()}
  defp do_process_blocks([], processed_blocks, block_tree, backlog, _chain, trie, _do_validation),
    do: {processed_blocks, block_tree, backlog, trie}

  defp do_process_blocks(
         [block | rest],
         processed_blocks,
         block_tree,
         backlog,
         chain,
         trie,
         do_validation
       ) do
    {processed_block_hash, new_block_tree, new_trie, new_backlog, extra_blocks} =
      case Blocktree.verify_and_add_block(
             block_tree,
             chain,
             block,
             trie,
             do_validation
           ) do
        {:invalid, [:non_genesis_block_requires_parent]} ->
          # Note: this is probably too slow since we see a lot of blocks without
          #       parents and, I think, we're running the full validity check.

          :ok =
            Logger.debug(fn -> "[Block Queue] Failed to verify block due to missing parent" end)

          updated_backlog =
            Map.update(
              backlog,
              block.header.parent_hash,
              [block],
              fn blocks -> [block | blocks] end
            )

          {nil, block_tree, trie, updated_backlog, []}

        {:invalid, reasons} ->
          :ok =
            Logger.debug(fn ->
              "[Block Queue] Failed to verify block ##{block.header.number} due to #{
                inspect(reasons)
              }"
            end)

          {nil, block_tree, trie, backlog, []}

        {:ok, {new_block_tree, new_trie, block_hash}} ->
          # Weird that we can't verify block 0....

          :ok =
            Logger.debug(fn ->
              "[Block Queue] Verified block ##{block.header.number} (0x#{
                Base.encode16(block_hash, case: :lower)
              })"
            end)

          {backlogged_blocks, new_backlog} = Map.pop(backlog, block_hash, [])

          {block_hash, new_block_tree, new_trie, new_backlog, backlogged_blocks}
      end

    do_process_blocks(
      extra_blocks ++ rest,
      if(processed_block_hash,
        do: [processed_block_hash | processed_blocks],
        else: processed_blocks
      ),
      new_block_tree,
      new_backlog,
      chain,
      new_trie,
      do_validation
    )
  end
end
