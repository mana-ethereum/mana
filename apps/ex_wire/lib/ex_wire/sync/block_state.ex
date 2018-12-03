defmodule ExWire.Sync.BlockState do
  @moduledoc """
  This module exposes functions to store and load the current state of
  a block sync in the database.
  """
  require Logger

  alias ExWire.Struct.BlockQueue
  alias MerklePatriciaTree.DB

  @key "current_block_queue_9"

  @doc """
  Loads the current block queue from database.
  """
  @spec load_block_queue(DB.db()) :: WarpQueue.t()
  def load_block_queue(db) do
    case DB.get(db, @key) do
      {:ok, current_block_queue} ->
        :erlang.binary_to_term(current_block_queue)

      :not_found ->
        %BlockQueue{}
    end
  end

  @doc """
  Stores the current block queue into the database.
  """
  @spec save_block_queue(DB.db(), BlockQueue.t()) :: :ok
  def save_block_queue(db, block_queue) do
    :ok = Logger.debug(fn -> "Saving block queue..." end)

    DB.put!(
      db,
      @key,
      :erlang.term_to_binary(%{
        block_queue
        | header_requests: MapSet.new(),
          block_requests: MapSet.new()
      })
    )

    :ok
  end
end
