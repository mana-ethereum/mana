defmodule EVM.GasTest do
  use ExUnit.Case, async: true
  doctest EVM.Gas

  test "Gas cost: CALL" do
    to_address = 0x0F572E5295C57F15886F9B263E2F6D2D6C7B5EC6
    inputs = [3000, to_address, 0, 0, 32, 32, 32]
    machine_state = %EVM.MachineState{program_counter: 0, stack: inputs}
    account_interface = EVM.Interface.Mock.MockAccountInterface.new()

    exec_env = %EVM.ExecEnv{
      machine_code: EVM.MachineCode.compile([:call]),
      address: to_address,
      account_interface: account_interface
    }

    cost = EVM.Gas.cost(machine_state, exec_env)

    assert cost == 28_046
  end

  describe "operation_cost/4" do
    test "calculated different costs for Frontier" do
      address = 0x0000000000000000000000000000000000000001
      account_interface = EVM.Interface.Mock.MockAccountInterface.new()

      exec_env = %EVM.ExecEnv{
        address: address,
        account_interface: account_interface,
        config: EVM.Configuration.Frontier.new()
      }

      assert 0 == EVM.Gas.operation_cost(:sstore, [], %EVM.MachineState{stack: [0, 0]}, exec_env)

      assert 10 == EVM.Gas.operation_cost(:exp, [0, 0], %EVM.MachineState{}, exec_env)

      assert 30 == EVM.Gas.operation_cost(:exp, [0, 1024], %EVM.MachineState{}, exec_env)

      assert 1 == EVM.Gas.operation_cost(:jumpdest, [], nil, exec_env)

      assert 20 == EVM.Gas.operation_cost(:blockhash, [], nil, exec_env)

      assert 0 == EVM.Gas.operation_cost(:stop, [], nil, exec_env)

      assert 2 == EVM.Gas.operation_cost(:address, [], nil, exec_env)

      assert 3 == EVM.Gas.operation_cost(:push0, [], nil, exec_env)

      assert 5 == EVM.Gas.operation_cost(:mul, [], nil, exec_env)

      assert 8 == EVM.Gas.operation_cost(:addmod, [], nil, exec_env)

      assert 10 == EVM.Gas.operation_cost(:jumpi, [], nil, exec_env)

      assert 20 == EVM.Gas.operation_cost(:extcodesize, [], nil, exec_env)

      assert 30 ==
               EVM.Gas.operation_cost(:sha3, [0, 0], %EVM.MachineState{stack: [0, 0]}, exec_env)

      assert 222 ==
               EVM.Gas.operation_cost(
                 :sha3,
                 [10, 1024],
                 %EVM.MachineState{stack: [10, 1024]},
                 exec_env
               )
    end
  end
end
