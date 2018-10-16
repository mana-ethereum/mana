defmodule EVM.VMTest do
  use ExUnit.Case, async: true
  doctest EVM.VM

  alias EVM.{VM, ExecEnv, SubState, MachineCode}
  alias EVM.Mock.MockAccountRepo

  setup do
    account_repo = MockAccountRepo.new()
    {:ok, %{account_repo: account_repo}}
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

    expected_sub_state = %SubState{}
    expected = {0, expected_sub_state, exec_env, <<0x08::256>>}

    assert result == expected
  end

  test "simple program with block storage", %{account_repo: account_repo} do
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
      account_repo: account_repo
    }

    result = VM.run(20_006, exec_env)

    expected_account_state = %{
      address => %{
        balance: 0,
        nonce: 0,
        code: <<>>,
        storage: %{5 => 3}
      }
    }

    expected_account_repo = MockAccountRepo.new(expected_account_state)
    expected_exec_env = Map.put(exec_env, :account_repo, expected_account_repo)
    expected_sub_state = %SubState{}

    expected = {0, expected_sub_state, expected_exec_env, ""}
    assert result == expected
  end
end
