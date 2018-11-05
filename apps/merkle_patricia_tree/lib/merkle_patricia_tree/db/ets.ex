defmodule MerklePatriciaTree.DB.ETS do
  @moduledoc """
  Implementation of `MerklePatriciaTree.DB` which
  is backed by :ets.
  """

  @behaviour MerklePatriciaTree.DB

  @doc """
  Performs initialization for this db.
  """
  @impl true
  def init(db_name) do
    ^db_name = :ets.new(db_name, [:set, :public, :named_table])

    {__MODULE__, db_name}
  end

  @doc """
  Retrieves a key from the database.
  """
  @impl true
  def get(db_ref, key) do
    case :ets.lookup(db_ref, key) do
      [{^key, v} | _rest] -> {:ok, v}
      _ -> :not_found
    end
  end

  @doc """
  Stores a key in the database.
  """
  @impl true
  def put!(db_ref, key, value) do
    case :ets.insert(db_ref, {key, value}) do
      true -> :ok
    end
  end

  @doc """
  Removes all objects with key from the database.
  """
  @impl true
  def delete!(db_ref, key) do
    case :ets.delete(db_ref, key) do
      true -> :ok
    end
  end

  @doc """
  Stores key-value pairs in the database.
  """
  @impl true
  def batch_put!(db_ref, key_value_pairs) do
    case :ets.insert(db_ref, key_value_pairs) do
      true -> :ok
    end
  end
end
