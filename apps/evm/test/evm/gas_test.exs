defmodule EVM.GasTest do
  use ExUnit.Case, async: true
  doctest EVM.Gas

  test "Gas cost: CALL" do
    db = MerklePatriciaTree.Test.random_ets_db()
    state = MerklePatriciaTree.Trie.new(db)
    machine_state = %EVM.MachineState{}
    operation = EVM.Operation.metadata(:call)
    to_address = 0x0f572e5295c57f15886f9b263e2f6d2d6c7b5ec6
    inputs = [3000, to_address, 0, 0, 32, 32, 32]
    cost = EVM.Gas.cost(state, machine_state, operation, inputs)

    assert cost == 3046
  end
end
