defmodule CLI.Sync do
  @moduledoc """
  Tools to sync new blocks.
  """
  require Logger

  alias Blockchain.{Blocktree, Chain}
  alias CLI.State
  alias MerklePatriciaTree.TrieStorage

  @type block_limit :: integer() | :infinite

  @save_block_interval 1000

  @doc """
  Recursively adds blocks to a tree. This function will
  run forever unless `max_new_blocks` is set, in which
  case it will add that many blocks and then return.
  """
  @spec sync_new_blocks(
          module(),
          any(),
          TrieStorage.t(),
          Chain.t(),
          Blocktree.t(),
          block_limit(),
          integer() | nil
        ) :: {:ok, Blocktree.t()} | {:error, any()}
  def sync_new_blocks(
        block_provider,
        block_provider_state,
        trie,
        chain,
        tree,
        block_number,
        block_limit \\ :infinite,
        highest_known_block_number \\ nil
      ) do
    case should_continue?(block_limit) do
      :stop ->
        {:ok, tree}

      {:continue, next_block_limit} ->
        with {:ok, next_block, next_block_provider_state} <-
               block_provider.get_block(block_number, block_provider_state) do
          case Blocktree.verify_and_add_block(tree, chain, next_block, trie) do
            {:ok, {next_tree, updated_trie}} ->
              track_progress(block_number, highest_known_block_number)

              updated_trie =
                if rem(block_number, @save_block_interval) == 0 do
                  # TODO: Does this log mess up our progress tracker?

                  committed_trie = TrieStorage.commit!(updated_trie)

                  committed_trie
                  |> TrieStorage.permanent_db()
                  |> State.save_tree(next_tree)

                  committed_trie
                else
                  updated_trie
                end

              sync_new_blocks(
                block_provider,
                next_block_provider_state,
                updated_trie,
                chain,
                next_tree,
                block_number + 1,
                next_block_limit,
                highest_known_block_number
              )

            {:invalid, error} ->
              _ = Logger.debug(fn -> "Failed block: #{inspect(next_block)}" end)

              _ =
                Logger.error(fn -> "Failed to verify block #{block_number}: #{inspect(error)}" end)

              committed_trie = TrieStorage.commit!(tree)

              committed_trie
              |> TrieStorage.permanent_db()
              |> State.save_tree(tree)

              {:error, error}
          end
        end
    end
  end

  @spec should_continue?(block_limit()) :: :stop | {:continue, block_limit()}
  defp should_continue?(:infinite), do: {:continue, :infinite}
  defp should_continue?(0), do: :stop
  defp should_continue?(n), do: {:continue, n - 1}

  @spec track_progress(integer(), integer() | nil) :: no_return()
  defp track_progress(block_number, _max_block_number) do
    # Let's currently just show till next sync block until we
    # can use `suffix: :count`
    ProgressBar.render(
      rem(block_number, @save_block_interval),
      @save_block_interval,
      progress_bar_format()
    )
  end

  @spec progress_bar_format([]) :: []
  defp progress_bar_format(opts \\ []) do
    Keyword.merge(
      [
        bar_color: [IO.ANSI.black(), IO.ANSI.green_background()],
        blank_color: IO.ANSI.white_background()
      ],
      opts
    )
  end
end
