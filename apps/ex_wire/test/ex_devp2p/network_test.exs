defmodule ExDevp2p.NetworkTest do
  use ExUnit.Case

  test "starting the network" do
    #network1 = %ExDevp2p.Network{port: 4447}
    #{:ok, pid} = GenServer.start_link(ExDevp2p.Network, :ok)

    #{:ok, socket} = :gen_udp.open(21339, [:binary])
    #:ok = :gen_udp.send(socket, '127.0.0.1', 21336, <<1>>)
    #IO.inspect pid

    #network2 = %ExDevp2p.Network{port: 4448}

    #ExDevp2p.Network.connect(network1, %{
    #  port: network2.port,
    #  address: network2.address,
    #})
  end
end

