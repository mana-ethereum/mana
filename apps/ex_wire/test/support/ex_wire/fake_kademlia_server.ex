defmodule ExWire.FakeKademliaServer do
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
