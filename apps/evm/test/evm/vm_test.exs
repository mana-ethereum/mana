defmodule EVM.VMTest do
  use ExUnit.Case, async: true
  doctest EVM.VM

  setup do
    db = MerklePatriciaTree.Test.random_ets_db(:contract_create_test)

    {:ok, %{
      state: MerklePatriciaTree.Trie.new(db)
    }}
  end

  test "simple program with return value", %{state: state} do
    instructions = [
      :push1,
      3,
      :push1,
      5,
      :add,
      :push1,
      0x00,
      :mstore,
      :push1,
      0,
      :push1,
      32,
      :return
    ]

    result = EVM.VM.run(state, 5, %EVM.ExecEnv{machine_code: EVM.MachineCode.compile(instructions)})

    assert result == {state, 5, %EVM.SubState{logs: "", refund: 0, suicide_list: []}, <<0x08::256>>}
  end

  test "simple program with block storage", %{state: state} do
    instructions = [
      :push1,
      3,
      :push1,
      5,
      :sstore,
      :stop
    ]

    result = EVM.VM.run(state, 5, %EVM.ExecEnv{machine_code: EVM.MachineCode.compile(instructions)})

    expected_state = %{state|root_hash: <<12, 189, 253, 61, 167, 240, 166, 67, 81, 179, 89, 188, 142, 220, 80, 44, 72, 102, 195, 89, 230, 27, 75, 136, 68, 2, 117, 227, 48, 141, 102, 230>>}

    assert result == {expected_state, 5, %EVM.SubState{logs: "", refund: 0, suicide_list: []}, ""}

    {returned_state, _, _, _} = result

    assert MerklePatriciaTree.Trie.Inspector.all_values(returned_state) == [{<<5::256>>, <<3::256>>}]
  end
end