defmodule EVM.VMTest do
  use ExUnit.Case, async: true
  doctest EVM.VM

  alias EVM.{VM, ExecEnv, SubState, MachineCode}
  alias EVM.Interface.Mock.MockAccountInterface

  setup do
    account_interface = MockAccountInterface.new()
    {:ok, %{account_interface: account_interface}}
  end

  test "simple program with return value", %{} do
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
      32,
      :push1,
      0,
      :return
    ]

    exec_env = %ExecEnv{machine_code: MachineCode.compile(instructions)}
    result = VM.run(24, exec_env)

    expected_sub_state = %SubState{logs: [], refund: 0, selfdestruct_list: []}
    expected = {0, expected_sub_state, exec_env, <<0x08::256>>}

    assert result == expected
  end

  test "simple program with block storage", %{account_interface: account_interface} do
    address = 0x0000000000000000000000000000000000000001

    instructions = [
      :push1,
      3,
      :push1,
      5,
      :sstore,
      :stop
    ]

    exec_env = %ExecEnv{
      machine_code: MachineCode.compile(instructions),
      address: address,
      account_interface: account_interface
    }

    result = VM.run(20006, exec_env)

    expected_account_state = %{
      address => %{
        balance: 0,
        nonce: 0,
        code: <<>>,
        storage: %{5 => 3}
      }
    }

    expected_account_interface = MockAccountInterface.new(expected_account_state)
    expected_exec_env = Map.put(exec_env, :account_interface, expected_account_interface)
    expected_sub_state = %SubState{logs: [], refund: 0, selfdestruct_list: []}

    expected = {20_000, expected_sub_state, expected_exec_env, ""}
    assert result == expected
  end
end
