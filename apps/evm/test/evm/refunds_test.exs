defmodule EVM.RefundsTest do
  use ExUnit.Case, async: true
  doctest EVM.Refunds

  setup do
    account_repo = EVM.Mock.MockAccountRepo.new()

    {:ok,
     %{
       account_repo: account_repo
     }}
  end

  test "Refund: SSTORE", %{account_repo: account_repo} do
    address = 0x0000000000000000000000000000000000000001

    instructions = [:push1, 3, :push1, 5, :sstore, :push1, 0, :push1, 5, :sstore, :stop]

    exec_env = %EVM.ExecEnv{
      machine_code: EVM.MachineCode.compile(instructions),
      address: address,
      account_repo: account_repo
    }

    result = EVM.VM.run(25_012, exec_env)

    expected_account_state = %{
      address => %{
        balance: 0,
        nonce: 0,
        storage: %{},
        code: ""
      }
    }

    expected_account_repo = EVM.Mock.MockAccountRepo.new(expected_account_state)

    expected_exec_env = Map.put(exec_env, :account_repo, expected_account_repo)

    assert result ==
             {0, %EVM.SubState{logs: [], refund: 15_000, selfdestruct_list: []},
              expected_exec_env, ""}
  end
end
