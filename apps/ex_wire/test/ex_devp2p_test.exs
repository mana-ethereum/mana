defmodule ExDevp2pTest do
  @network_adapter Application.get_env(:ex_devp2p, :network_adapter)
  use ExUnit.Case
  doctest ExDevp2p

  test "`ping` triggers a `pong` " do
    ping = :binary.encode_unsigned(0x0607c19d05f05b58ef12a371eb5749bdf9887ea46be9cc93dc95cad24ad2f98122a78db1ddd42ee1715607d460f9d108df92d621a90f75296ffe8130df310dfb642d47f40968e304f5282cc042728e6fd0e445704ce7382d11de56af7248d3590001da04c784000000008080cb847f00000182765f82000084595005a1)

    # @network_adapter.handle_info({:udp, nil, nil, nil, ping}, %{})
    #ExDevp2p.Network.handle_info({:udp, nil, nil, nil, ping}, %{})
  end
end
