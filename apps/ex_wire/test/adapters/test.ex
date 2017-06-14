defmodule ExDevp2p.Adapters.Test do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end
end
