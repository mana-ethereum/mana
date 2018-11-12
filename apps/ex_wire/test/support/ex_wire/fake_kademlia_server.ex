defmodule ExWire.FakeKademliaServer do
  @moduledoc """
  GenServer to mimic the behaviour of the real Kademlia server, meant to
  reduce dependencies in tests that rely on Kademlia indirectly.
  """
  use GenServer

  def start_link(neighbours) do
    GenServer.start_link(__MODULE__, {neighbours})
  end

  @impl true
  def init({neighbours}) do
    {:ok, %{neighbours: neighbours}}
  end

  @impl true
  def handle_call(
        {:neighbours, _find_neighbours, _endpoint},
        _from,
        state = %{neighbours: neighbours}
      ) do
    {:reply, neighbours, state}
  end
end
