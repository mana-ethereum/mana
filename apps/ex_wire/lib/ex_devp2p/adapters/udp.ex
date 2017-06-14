defmodule ExDevp2p.Adapters.UDP do
  use GenServer
  @port 30303

  def start_link(network) do
    GenServer.start_link(__MODULE__, %{network: network})
  end

  def init (state) do
    {:ok, socket} = :gen_udp.open(@port, [:binary])
    state = Map.put(state, :socket, socket)
    {:ok, state}
  end

  def handle_info({:udp, _socket, _ip, _port, data}, state = %{network: network}) do
    network.receive(data, self())
    {:noreply, state}
  end

  def handle_cast({
      :send,
      %{to: %{ip: ip, udp_port: udp_port}, data: data}
    }, state = %{socket: socket}) do
    :gen_udp.send(socket, ip, udp_port, data)
    {:noreply, state}
  end
end
