defmodule ExWire.Adapter.Test do
  use GenServer

  def start_link(params) do
    name = Keyword.fetch!(params, :name)
    {module, args} = Keyword.fetch!(params, :network_module)
    port = Keyword.fetch!(params, :port)

    GenServer.start_link(
      __MODULE__,
      %{network: module, network_args: args, port: port},
      name: name
    )
  end

  def init(state) do
    {:ok, state}
  end

  def handle_cast({:listen, callback}, state) do
    state = Map.put(state, :callback, callback)
    {:noreply, state}
  end

  def handle_cast({:send, data}, state) do
    send(:test, data)
    {:noreply, state}
  end

  def handle_cast(
        {:fake_receive,
         %{
           data: data,
           remote_host: remote_host,
           timestamp: timestamp
         }, options},
        state = %{network: network}
      ) do
    network.receive(%ExWire.Network.InboundMessage{
      data: data,
      server_pid: self(),
      remote_host: remote_host,
      timestamp: timestamp,
      handler_pid: Keyword.get(options, :kademlia_process_name)
    })

    {:noreply, state}
  end
end
