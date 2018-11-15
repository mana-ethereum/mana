defmodule CLI.State do
  @moduledoc """
  The CLI state gen server would hold the current syncing chain properties set at start.
  As a named process it could subscribe to current block and highest block changes during the sync.
  """
  use GenServer

  def start_link(chain) do
    GenServer.start_link(__MODULE__, chain, name: __MODULE__)
  end

  def init(_chain) do
    {:ok, %{}}
  end
end
