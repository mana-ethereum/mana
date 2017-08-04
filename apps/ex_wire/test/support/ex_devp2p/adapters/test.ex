defmodule ExDevp2p.Adapters.Test do
  use GenServer

  def start_link(network) do
    GenServer.start_link(__MODULE__, %{network: network})
  end

  def init(state) do
    Process.register self(), :test_network_adapter
    {:ok, state}
  end

  def handle_cast({:listen, callback}, state) do
    state = Map.put(state, :callback, callback)
    {:noreply, state}
  end

  def handle_cast({:send, data}, state) do
    send :test, data
    {:noreply, state}
  end

  def handle_cast({:fake_recieve, %{
      data: data,
      remote_host: remote_host,
    }},
    state = %{network: network}) do
      network.receive(%{
        data: data,
        pid: self(),
        remote_host: remote_host,
      })

    {:noreply, state}
  end
end
