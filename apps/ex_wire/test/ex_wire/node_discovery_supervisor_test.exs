defmodule ExWire.NodeDiscoverySupervisorTest do
  use ExUnit.Case, async: true
  alias ExWire.NodeDiscoverySupervisor

  test "current_node/1" do
    assert %ExWire.Kademlia.Node{} = NodeDiscoverySupervisor.current_node([])
  end
end
