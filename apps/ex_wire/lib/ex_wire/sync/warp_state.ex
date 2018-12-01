defmodule ExWire.Sync.WarpState do
  @moduledoc """
  Warp may take some time, and thus we want to occasionally snapshot
  the current state of a warp in case our process exits before the
  warp is complete. When we restart the process, we can try and continue
  from where the warp left off.

  This module exposes functions to store and load the current state of
  a warp in the database.
  """
  require Logger

  alias Exth.Time
  alias ExWire.Struct.WarpQueue
  alias MerklePatriciaTree.DB

  @key "current_warp_queue"

  @doc """
  Loads the current warp queue from database.
  """
  @spec load_warp_queue(DB.db()) :: WarpQueue.t()
  def load_warp_queue(db) do
    case DB.get(db, @key) do
      {:ok, current_warp_queue} ->
        warp_queue = :erlang.binary_to_term(current_warp_queue)

        %{
          warp_queue
          | warp_start: Time.time_start()
        }

      :not_found ->
        WarpQueue.new()
    end
  end

  @doc """
  Stores the current block tree into the database.
  """
  @spec save_warp_queue(DB.db(), WarpQueue.t()) :: :ok
  def save_warp_queue(db, warp_queue) do
    :ok = Logger.debug(fn -> "Saving warp queue..." end)

    DB.put!(
      db,
      @key,
      :erlang.term_to_binary(%{
        warp_queue
        | chunk_requests: MapSet.new(),
          retrieved_chunks: MapSet.new()
      })
    )

    :ok
  end
end
